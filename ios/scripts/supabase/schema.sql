-- PayBoard normalized backup schema
-- IMPORTANT:
-- 1) This migration moves backup storage from JSON payload snapshots to normalized tables.
-- 2) It also drops payload columns from public.subscription_latest_backups.
-- 3) Run this only after the app/server has been updated to read/write the new tables.
-- Safe to run multiple times.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Normalized tables
-- ---------------------------------------------------------------------------

create table if not exists public.subscription_items (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    name text not null,
    category text not null check (
        category in (
            'video',
            'music',
            'productivity',
            'cloud',
            'housing',
            'shopping',
            'gaming',
            'finance',
            'education',
            'health',
            'other'
        )
    ),
    amount numeric(18, 2) not null default 0,
    is_amount_undecided boolean not null default false,
    currency_code text not null default 'KRW',
    billing_cycle_kind text not null check (
        billing_cycle_kind in ('monthly', 'yearly', 'custom_days')
    ),
    billing_cycle_days integer not null default 30 check (billing_cycle_days > 0),
    next_billing_date timestamptz not null,
    last_payment_date timestamptz,
    icon_key text not null,
    icon_color_key text not null default 'blue',
    custom_category_name text,
    notifications_enabled boolean not null default true,
    is_auto_pay_enabled boolean not null default false,
    is_pinned boolean not null default false,
    is_active boolean not null default true,
    memo text,
    sort_order integer not null default 0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.subscription_payment_histories (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    subscription_id uuid not null references public.subscription_items(id) on delete cascade,
    paid_at timestamptz not null,
    scheduled_date timestamptz not null,
    amount_snapshot numeric(18, 2) not null default 0,
    currency_code text not null default 'KRW',
    is_auto_pay boolean not null default false,
    status text not null default 'paid' check (status in ('paid', 'canceled')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (subscription_id, paid_at, status)
);

create index if not exists idx_subscription_items_user_id
    on public.subscription_items (user_id);

create index if not exists idx_subscription_items_user_active_next_billing
    on public.subscription_items (user_id, is_active, next_billing_date);

create index if not exists idx_subscription_items_user_pinned_sort
    on public.subscription_items (user_id, is_pinned desc, sort_order asc, updated_at desc);

create index if not exists idx_subscription_payment_histories_user_paid_at
    on public.subscription_payment_histories (user_id, paid_at desc);

create index if not exists idx_subscription_payment_histories_subscription_paid_at
    on public.subscription_payment_histories (subscription_id, paid_at desc);

alter table public.subscription_items enable row level security;
alter table public.subscription_payment_histories enable row level security;

drop policy if exists "subscription_items_select_own" on public.subscription_items;
create policy "subscription_items_select_own"
    on public.subscription_items
    for select
    using (auth.uid() = user_id);

drop policy if exists "subscription_items_mutate_own" on public.subscription_items;
create policy "subscription_items_mutate_own"
    on public.subscription_items
    for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

drop policy if exists "subscription_payment_histories_select_own" on public.subscription_payment_histories;
create policy "subscription_payment_histories_select_own"
    on public.subscription_payment_histories
    for select
    using (auth.uid() = user_id);

drop policy if exists "subscription_payment_histories_mutate_own" on public.subscription_payment_histories;
create policy "subscription_payment_histories_mutate_own"
    on public.subscription_payment_histories
    for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Payload -> normalized migration helpers
-- ---------------------------------------------------------------------------
-- Notes:
-- - paymentHistoryDates stores only paid timestamps in the current app model.
-- - scheduled_date is backfilled with paid_at because exact due date is not
--   present in historical payload data.
-- - cancel events cannot be reconstructed from the old payload and are not
--   backfilled.

do $$
begin
    if exists (
        select 1
        from information_schema.tables
        where table_schema = 'public'
          and table_name = 'subscription_latest_backups'
    ) and exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'subscription_latest_backups'
          and column_name = 'payload'
    ) then
        insert into public.subscription_items (
            id,
            user_id,
            name,
            category,
            amount,
            is_amount_undecided,
            currency_code,
            billing_cycle_kind,
            billing_cycle_days,
            next_billing_date,
            last_payment_date,
            icon_key,
            icon_color_key,
            custom_category_name,
            notifications_enabled,
            is_auto_pay_enabled,
            is_pinned,
            is_active,
            memo,
            sort_order,
            created_at,
            updated_at
        )
        select
            (item ->> 'id')::uuid as id,
            b.user_id,
            coalesce(nullif(item ->> 'name', ''), 'Untitled'),
            case
                when item ->> 'category' in (
                    'video',
                    'music',
                    'productivity',
                    'cloud',
                    'housing',
                    'shopping',
                    'gaming',
                    'finance',
                    'education',
                    'health',
                    'other'
                ) then item ->> 'category'
                else 'other'
            end as category,
            coalesce(nullif(item ->> 'amount', '')::numeric(18, 2), 0) as amount,
            coalesce((item ->> 'isAmountUndecided')::boolean, false) as is_amount_undecided,
            coalesce(nullif(item ->> 'currencyCode', ''), 'KRW') as currency_code,
            case
                when (item -> 'billingCycle') ? 'monthly' then 'monthly'
                when (item -> 'billingCycle') ? 'yearly' then 'yearly'
                when (item -> 'billingCycle') ? 'customDays' then 'custom_days'
                else 'monthly'
            end as billing_cycle_kind,
            case
                when (item -> 'billingCycle') ? 'customDays' then greatest(
                    coalesce(
                        nullif(item #>> '{billingCycle,customDays,_0}', '')::integer,
                        nullif(item #>> '{billingCycle,customDays}', '')::integer,
                        30
                    ),
                    1
                )
                when (item -> 'billingCycle') ? 'yearly' then 365
                else 30
            end as billing_cycle_days,
            coalesce(
                nullif(item ->> 'nextBillingDate', '')::timestamptz,
                b.updated_at,
                now()
            ) as next_billing_date,
            nullif(item ->> 'lastPaymentDate', '')::timestamptz as last_payment_date,
            coalesce(nullif(item ->> 'iconKey', ''), 'questionmark.circle') as icon_key,
            coalesce(nullif(item ->> 'iconColorKey', ''), 'blue') as icon_color_key,
            nullif(item ->> 'customCategoryName', '') as custom_category_name,
            coalesce((item ->> 'notificationsEnabled')::boolean, true) as notifications_enabled,
            coalesce((item ->> 'isAutoPayEnabled')::boolean, false) as is_auto_pay_enabled,
            coalesce((item ->> 'isPinned')::boolean, false) as is_pinned,
            coalesce((item ->> 'isActive')::boolean, true) as is_active,
            nullif(item ->> 'memo', '') as memo,
            item_ordinality::integer as sort_order,
            coalesce(
                nullif(item ->> 'createdAt', '')::timestamptz,
                b.created_at,
                now()
            ) as created_at,
            coalesce(
                nullif(item ->> 'updatedAt', '')::timestamptz,
                b.updated_at,
                now()
            ) as updated_at
        from public.subscription_latest_backups b
        cross join lateral jsonb_array_elements(coalesce(b.payload, '[]'::jsonb))
            with ordinality as payload_items(item, item_ordinality)
        where nullif(item ->> 'id', '') is not null
        on conflict (id) do update
        set
            user_id = excluded.user_id,
            name = excluded.name,
            category = excluded.category,
            amount = excluded.amount,
            is_amount_undecided = excluded.is_amount_undecided,
            currency_code = excluded.currency_code,
            billing_cycle_kind = excluded.billing_cycle_kind,
            billing_cycle_days = excluded.billing_cycle_days,
            next_billing_date = excluded.next_billing_date,
            last_payment_date = excluded.last_payment_date,
            icon_key = excluded.icon_key,
            icon_color_key = excluded.icon_color_key,
            custom_category_name = excluded.custom_category_name,
            notifications_enabled = excluded.notifications_enabled,
            is_auto_pay_enabled = excluded.is_auto_pay_enabled,
            is_pinned = excluded.is_pinned,
            is_active = excluded.is_active,
            memo = excluded.memo,
            sort_order = excluded.sort_order,
            created_at = excluded.created_at,
            updated_at = excluded.updated_at;

        insert into public.subscription_payment_histories (
            user_id,
            subscription_id,
            paid_at,
            scheduled_date,
            amount_snapshot,
            currency_code,
            is_auto_pay,
            status,
            created_at,
            updated_at
        )
        select
            source.user_id,
            source.subscription_id,
            source.paid_at,
            source.paid_at as scheduled_date,
            source.amount_snapshot,
            source.currency_code,
            source.is_auto_pay,
            'paid' as status,
            source.created_at,
            source.updated_at
        from (
            select distinct
                b.user_id,
                (item ->> 'id')::uuid as subscription_id,
                history_dates.paid_at,
                coalesce(nullif(item ->> 'amount', '')::numeric(18, 2), 0) as amount_snapshot,
                coalesce(nullif(item ->> 'currencyCode', ''), 'KRW') as currency_code,
                coalesce((item ->> 'isAutoPayEnabled')::boolean, false) as is_auto_pay,
                coalesce(
                    nullif(item ->> 'createdAt', '')::timestamptz,
                    b.created_at,
                    now()
                ) as created_at,
                coalesce(
                    nullif(item ->> 'updatedAt', '')::timestamptz,
                    b.updated_at,
                    now()
                ) as updated_at
            from public.subscription_latest_backups b
            cross join lateral jsonb_array_elements(coalesce(b.payload, '[]'::jsonb)) as payload_items(item)
            cross join lateral (
                select paid_at
                from (
                    select jsonb_array_elements_text(
                        coalesce(item -> 'paymentHistoryDates', '[]'::jsonb)
                    )::timestamptz as paid_at
                    union
                    select nullif(item ->> 'lastPaymentDate', '')::timestamptz as paid_at
                ) raw_dates
                where paid_at is not null
            ) as history_dates
            where nullif(item ->> 'id', '') is not null
        ) source
        on conflict (subscription_id, paid_at, status) do nothing;
    end if;
end
$$;

do $$
begin
    if exists (
        select 1
        from information_schema.tables
        where table_schema = 'public'
          and table_name = 'subscription_backups'
    ) and exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'subscription_backups'
          and column_name = 'payload'
    ) then
        if exists (
            select 1
            from information_schema.tables
            where table_schema = 'public'
              and table_name = 'subscription_latest_backups'
        ) then
            insert into public.subscription_items (
                id,
                user_id,
                name,
                category,
                amount,
                is_amount_undecided,
                currency_code,
                billing_cycle_kind,
                billing_cycle_days,
                next_billing_date,
                last_payment_date,
                icon_key,
                icon_color_key,
                custom_category_name,
                notifications_enabled,
                is_auto_pay_enabled,
                is_pinned,
                is_active,
                memo,
                sort_order,
                created_at,
                updated_at
            )
            select
                (item ->> 'id')::uuid as id,
                legacy.user_id,
                coalesce(nullif(item ->> 'name', ''), 'Untitled'),
                case
                    when item ->> 'category' in (
                        'video',
                        'music',
                        'productivity',
                        'cloud',
                        'housing',
                        'shopping',
                        'gaming',
                        'finance',
                        'education',
                        'health',
                        'other'
                    ) then item ->> 'category'
                    else 'other'
                end as category,
                coalesce(nullif(item ->> 'amount', '')::numeric(18, 2), 0) as amount,
                coalesce((item ->> 'isAmountUndecided')::boolean, false) as is_amount_undecided,
                coalesce(nullif(item ->> 'currencyCode', ''), 'KRW') as currency_code,
                case
                    when (item -> 'billingCycle') ? 'monthly' then 'monthly'
                    when (item -> 'billingCycle') ? 'yearly' then 'yearly'
                    when (item -> 'billingCycle') ? 'customDays' then 'custom_days'
                    else 'monthly'
                end as billing_cycle_kind,
                case
                    when (item -> 'billingCycle') ? 'customDays' then greatest(
                        coalesce(
                            nullif(item #>> '{billingCycle,customDays,_0}', '')::integer,
                            nullif(item #>> '{billingCycle,customDays}', '')::integer,
                            30
                        ),
                        1
                    )
                    when (item -> 'billingCycle') ? 'yearly' then 365
                    else 30
                end as billing_cycle_days,
                coalesce(
                    nullif(item ->> 'nextBillingDate', '')::timestamptz,
                    legacy.created_at,
                    now()
                ) as next_billing_date,
                nullif(item ->> 'lastPaymentDate', '')::timestamptz as last_payment_date,
                coalesce(nullif(item ->> 'iconKey', ''), 'questionmark.circle') as icon_key,
                coalesce(nullif(item ->> 'iconColorKey', ''), 'blue') as icon_color_key,
                nullif(item ->> 'customCategoryName', '') as custom_category_name,
                coalesce((item ->> 'notificationsEnabled')::boolean, true) as notifications_enabled,
                coalesce((item ->> 'isAutoPayEnabled')::boolean, false) as is_auto_pay_enabled,
                coalesce((item ->> 'isPinned')::boolean, false) as is_pinned,
                coalesce((item ->> 'isActive')::boolean, true) as is_active,
                nullif(item ->> 'memo', '') as memo,
                item_ordinality::integer as sort_order,
                coalesce(
                    nullif(item ->> 'createdAt', '')::timestamptz,
                    legacy.created_at,
                    now()
                ) as created_at,
                coalesce(
                    nullif(item ->> 'updatedAt', '')::timestamptz,
                    legacy.created_at,
                    now()
                ) as updated_at
            from (
                select distinct on (b.user_id)
                    b.user_id,
                    b.payload,
                    b.created_at
                from public.subscription_backups b
                where not exists (
                    select 1
                    from public.subscription_latest_backups latest
                    where latest.user_id = b.user_id
                )
                order by b.user_id, b.created_at desc
            ) legacy
            cross join lateral jsonb_array_elements(coalesce(legacy.payload, '[]'::jsonb))
                with ordinality as payload_items(item, item_ordinality)
            where nullif(item ->> 'id', '') is not null
            on conflict (id) do nothing;

            insert into public.subscription_payment_histories (
                user_id,
                subscription_id,
                paid_at,
                scheduled_date,
                amount_snapshot,
                currency_code,
                is_auto_pay,
                status,
                created_at,
                updated_at
            )
            select
                source.user_id,
                source.subscription_id,
                source.paid_at,
                source.paid_at as scheduled_date,
                source.amount_snapshot,
                source.currency_code,
                source.is_auto_pay,
                'paid' as status,
                source.created_at,
                source.updated_at
            from (
                select distinct
                    legacy.user_id,
                    (item ->> 'id')::uuid as subscription_id,
                    history_dates.paid_at,
                    coalesce(nullif(item ->> 'amount', '')::numeric(18, 2), 0) as amount_snapshot,
                    coalesce(nullif(item ->> 'currencyCode', ''), 'KRW') as currency_code,
                    coalesce((item ->> 'isAutoPayEnabled')::boolean, false) as is_auto_pay,
                    coalesce(
                        nullif(item ->> 'createdAt', '')::timestamptz,
                        legacy.created_at,
                        now()
                    ) as created_at,
                    coalesce(
                        nullif(item ->> 'updatedAt', '')::timestamptz,
                        legacy.created_at,
                        now()
                    ) as updated_at
                from (
                    select distinct on (b.user_id)
                        b.user_id,
                        b.payload,
                        b.created_at
                    from public.subscription_backups b
                    where not exists (
                        select 1
                        from public.subscription_latest_backups latest
                        where latest.user_id = b.user_id
                    )
                    order by b.user_id, b.created_at desc
                ) legacy
                cross join lateral jsonb_array_elements(coalesce(legacy.payload, '[]'::jsonb)) as payload_items(item)
                cross join lateral (
                    select paid_at
                    from (
                        select jsonb_array_elements_text(
                            coalesce(item -> 'paymentHistoryDates', '[]'::jsonb)
                        )::timestamptz as paid_at
                        union
                        select nullif(item ->> 'lastPaymentDate', '')::timestamptz as paid_at
                    ) raw_dates
                    where paid_at is not null
                ) as history_dates
                where nullif(item ->> 'id', '') is not null
            ) source
            on conflict (subscription_id, paid_at, status) do nothing;
        else
            insert into public.subscription_items (
                id,
                user_id,
                name,
                category,
                amount,
                is_amount_undecided,
                currency_code,
                billing_cycle_kind,
                billing_cycle_days,
                next_billing_date,
                last_payment_date,
                icon_key,
                icon_color_key,
                custom_category_name,
                notifications_enabled,
                is_auto_pay_enabled,
                is_pinned,
                is_active,
                memo,
                sort_order,
                created_at,
                updated_at
            )
            select
                (item ->> 'id')::uuid as id,
                legacy.user_id,
                coalesce(nullif(item ->> 'name', ''), 'Untitled'),
                case
                    when item ->> 'category' in (
                        'video',
                        'music',
                        'productivity',
                        'cloud',
                        'housing',
                        'shopping',
                        'gaming',
                        'finance',
                        'education',
                        'health',
                        'other'
                    ) then item ->> 'category'
                    else 'other'
                end as category,
                coalesce(nullif(item ->> 'amount', '')::numeric(18, 2), 0) as amount,
                coalesce((item ->> 'isAmountUndecided')::boolean, false) as is_amount_undecided,
                coalesce(nullif(item ->> 'currencyCode', ''), 'KRW') as currency_code,
                case
                    when (item -> 'billingCycle') ? 'monthly' then 'monthly'
                    when (item -> 'billingCycle') ? 'yearly' then 'yearly'
                    when (item -> 'billingCycle') ? 'customDays' then 'custom_days'
                    else 'monthly'
                end as billing_cycle_kind,
                case
                    when (item -> 'billingCycle') ? 'customDays' then greatest(
                        coalesce(
                            nullif(item #>> '{billingCycle,customDays,_0}', '')::integer,
                            nullif(item #>> '{billingCycle,customDays}', '')::integer,
                            30
                        ),
                        1
                    )
                    when (item -> 'billingCycle') ? 'yearly' then 365
                    else 30
                end as billing_cycle_days,
                coalesce(
                    nullif(item ->> 'nextBillingDate', '')::timestamptz,
                    legacy.created_at,
                    now()
                ) as next_billing_date,
                nullif(item ->> 'lastPaymentDate', '')::timestamptz as last_payment_date,
                coalesce(nullif(item ->> 'iconKey', ''), 'questionmark.circle') as icon_key,
                coalesce(nullif(item ->> 'iconColorKey', ''), 'blue') as icon_color_key,
                nullif(item ->> 'customCategoryName', '') as custom_category_name,
                coalesce((item ->> 'notificationsEnabled')::boolean, true) as notifications_enabled,
                coalesce((item ->> 'isAutoPayEnabled')::boolean, false) as is_auto_pay_enabled,
                coalesce((item ->> 'isPinned')::boolean, false) as is_pinned,
                coalesce((item ->> 'isActive')::boolean, true) as is_active,
                nullif(item ->> 'memo', '') as memo,
                item_ordinality::integer as sort_order,
                coalesce(
                    nullif(item ->> 'createdAt', '')::timestamptz,
                    legacy.created_at,
                    now()
                ) as created_at,
                coalesce(
                    nullif(item ->> 'updatedAt', '')::timestamptz,
                    legacy.created_at,
                    now()
                ) as updated_at
            from (
                select distinct on (b.user_id)
                    b.user_id,
                    b.payload,
                    b.created_at
                from public.subscription_backups b
                order by b.user_id, b.created_at desc
            ) legacy
            cross join lateral jsonb_array_elements(coalesce(legacy.payload, '[]'::jsonb))
                with ordinality as payload_items(item, item_ordinality)
            where nullif(item ->> 'id', '') is not null
            on conflict (id) do nothing;

            insert into public.subscription_payment_histories (
                user_id,
                subscription_id,
                paid_at,
                scheduled_date,
                amount_snapshot,
                currency_code,
                is_auto_pay,
                status,
                created_at,
                updated_at
            )
            select
                source.user_id,
                source.subscription_id,
                source.paid_at,
                source.paid_at as scheduled_date,
                source.amount_snapshot,
                source.currency_code,
                source.is_auto_pay,
                'paid' as status,
                source.created_at,
                source.updated_at
            from (
                select distinct
                    legacy.user_id,
                    (item ->> 'id')::uuid as subscription_id,
                    history_dates.paid_at,
                    coalesce(nullif(item ->> 'amount', '')::numeric(18, 2), 0) as amount_snapshot,
                    coalesce(nullif(item ->> 'currencyCode', ''), 'KRW') as currency_code,
                    coalesce((item ->> 'isAutoPayEnabled')::boolean, false) as is_auto_pay,
                    coalesce(
                        nullif(item ->> 'createdAt', '')::timestamptz,
                        legacy.created_at,
                        now()
                    ) as created_at,
                    coalesce(
                        nullif(item ->> 'updatedAt', '')::timestamptz,
                        legacy.created_at,
                        now()
                    ) as updated_at
                from (
                    select distinct on (b.user_id)
                        b.user_id,
                        b.payload,
                        b.created_at
                    from public.subscription_backups b
                    order by b.user_id, b.created_at desc
                ) legacy
                cross join lateral jsonb_array_elements(coalesce(legacy.payload, '[]'::jsonb)) as payload_items(item)
                cross join lateral (
                    select paid_at
                    from (
                        select jsonb_array_elements_text(
                            coalesce(item -> 'paymentHistoryDates', '[]'::jsonb)
                        )::timestamptz as paid_at
                        union
                        select nullif(item ->> 'lastPaymentDate', '')::timestamptz as paid_at
                    ) raw_dates
                    where paid_at is not null
                ) as history_dates
                where nullif(item ->> 'id', '') is not null
            ) source
            on conflict (subscription_id, paid_at, status) do nothing;
        end if;
    end if;
end
$$;

-- ---------------------------------------------------------------------------
-- Drop JSON payload columns after normalized data migration
-- ---------------------------------------------------------------------------

do $$
begin
    if exists (
        select 1
        from information_schema.tables
        where table_schema = 'public'
          and table_name = 'subscription_latest_backups'
    ) then
        alter table public.subscription_latest_backups
            drop column if exists payload,
            drop column if exists payload_sha256;
    end if;
end
$$;
