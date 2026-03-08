package kr.co.cdd.payboard.core.designsystem.i18n

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import kr.co.cdd.payboard.core.domain.model.AppAppearance
import kr.co.cdd.payboard.core.domain.model.AppLanguage
import kr.co.cdd.payboard.core.domain.model.InitialScreen
import kr.co.cdd.payboard.core.domain.model.ReminderOption
import kr.co.cdd.payboard.core.domain.model.SubscriptionCategory
import java.math.BigDecimal
import java.text.NumberFormat
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

@Immutable
class PayBoardStrings(
    val language: AppLanguage,
) {
    val locale: Locale = Locale.forLanguageTag(language.code)

    val routeBoard: String = when (language) {
        AppLanguage.KOREAN -> "보드"
        AppLanguage.ENGLISH -> "Board"
    }
    val routeCalendar: String = when (language) {
        AppLanguage.KOREAN -> "캘린더"
        AppLanguage.ENGLISH -> "Calendar"
    }
    val routeArchive: String = when (language) {
        AppLanguage.KOREAN -> "보관함"
        AppLanguage.ENGLISH -> "Archive"
    }
    val routeSettings: String = when (language) {
        AppLanguage.KOREAN -> "설정"
        AppLanguage.ENGLISH -> "Settings"
    }

    val boardLabel: String = when (language) {
        AppLanguage.KOREAN -> "보드"
        AppLanguage.ENGLISH -> "Board"
    }
    val calendarLabel: String = when (language) {
        AppLanguage.KOREAN -> "캘린더"
        AppLanguage.ENGLISH -> "Calendar"
    }
    val searchSubscriptions: String = when (language) {
        AppLanguage.KOREAN -> "구독 검색"
        AppLanguage.ENGLISH -> "Search subscriptions"
    }
    val sortTitle: String = when (language) {
        AppLanguage.KOREAN -> "정렬"
        AppLanguage.ENGLISH -> "Sort"
    }
    val filter: String = when (language) {
        AppLanguage.KOREAN -> "필터"
        AppLanguage.ENGLISH -> "Filter"
    }
    val layout: String = when (language) {
        AppLanguage.KOREAN -> "레이아웃"
        AppLanguage.ENGLISH -> "Layout"
    }
    val sortNextBillingAsc: String = when (language) {
        AppLanguage.KOREAN -> "결제일 빠른순"
        AppLanguage.ENGLISH -> "Due date (soon)"
    }
    val sortNextBillingDesc: String = when (language) {
        AppLanguage.KOREAN -> "결제일 느린순"
        AppLanguage.ENGLISH -> "Due date (later)"
    }
    val sortNameAsc: String = when (language) {
        AppLanguage.KOREAN -> "이름순"
        AppLanguage.ENGLISH -> "Name"
    }
    val sortAmountDesc: String = when (language) {
        AppLanguage.KOREAN -> "금액 높은순"
        AppLanguage.ENGLISH -> "Amount (high)"
    }
    val sortCustom: String = when (language) {
        AppLanguage.KOREAN -> "커스텀"
        AppLanguage.ENGLISH -> "Custom"
    }
    val layoutSmall: String = when (language) {
        AppLanguage.KOREAN -> "작게"
        AppLanguage.ENGLISH -> "Small"
    }
    val layoutNormal: String = when (language) {
        AppLanguage.KOREAN -> "보통"
        AppLanguage.ENGLISH -> "Normal"
    }
    val layoutMax: String = when (language) {
        AppLanguage.KOREAN -> "최대"
        AppLanguage.ENGLISH -> "Max"
    }
    val monthlyTotal: String = when (language) {
        AppLanguage.KOREAN -> "이번 달 합계"
        AppLanguage.ENGLISH -> "This month total"
    }
    val categorySummary: String = when (language) {
        AppLanguage.KOREAN -> "카테고리 요약"
        AppLanguage.ENGLISH -> "Category summary"
    }
    val noActiveSubscriptions: String = when (language) {
        AppLanguage.KOREAN -> "활성 구독이 없습니다"
        AppLanguage.ENGLISH -> "No active subscriptions"
    }
    val noSubscriptionsYet: String = when (language) {
        AppLanguage.KOREAN -> "아직 구독 항목이 없습니다"
        AppLanguage.ENGLISH -> "No subscriptions yet"
    }
    val boardEmptyCaption: String = when (language) {
        AppLanguage.KOREAN -> "다음 단계는 서비스 편집기와 더 풍부한 캘린더 제어를 붙이는 것입니다."
        AppLanguage.ENGLISH -> "The next UI pass is the editor and richer calendar controls."
    }
    val addSubscription: String = when (language) {
        AppLanguage.KOREAN -> "구독 추가"
        AppLanguage.ENGLISH -> "Add subscription"
    }
    val editSubscription: String = when (language) {
        AppLanguage.KOREAN -> "구독 수정"
        AppLanguage.ENGLISH -> "Edit subscription"
    }
    val markAsPaid: String = when (language) {
        AppLanguage.KOREAN -> "결제 완료로 표시"
        AppLanguage.ENGLISH -> "Mark as paid"
    }
    val archive: String = when (language) {
        AppLanguage.KOREAN -> "보관"
        AppLanguage.ENGLISH -> "Archive"
    }
    val upcoming: String = when (language) {
        AppLanguage.KOREAN -> "예정"
        AppLanguage.ENGLISH -> "Upcoming"
    }
    val paid: String = when (language) {
        AppLanguage.KOREAN -> "완료"
        AppLanguage.ENGLISH -> "Paid"
    }
    val upcomingBillingItems: String = when (language) {
        AppLanguage.KOREAN -> "이번 달 예정된 결제 항목"
        AppLanguage.ENGLISH -> "Upcoming billing items in this month"
    }
    val calendarEmptyForDate: String = when (language) {
        AppLanguage.KOREAN -> "선택한 날짜에는 구독 항목이 없습니다."
        AppLanguage.ENGLISH -> "No subscriptions for the selected date."
    }
    val cardActions: String = when (language) {
        AppLanguage.KOREAN -> "카드 작업"
        AppLanguage.ENGLISH -> "Card actions"
    }
    val changeIcon: String = when (language) {
        AppLanguage.KOREAN -> "아이콘 변경"
        AppLanguage.ENGLISH -> "Change icon"
    }
    val iconSearch: String = when (language) {
        AppLanguage.KOREAN -> "아이콘 검색"
        AppLanguage.ENGLISH -> "Search icons"
    }
    val nextBilling: String = when (language) {
        AppLanguage.KOREAN -> "다음 결제"
        AppLanguage.ENGLISH -> "Next billing"
    }
    val paymentStatus: String = when (language) {
        AppLanguage.KOREAN -> "결제 상태"
        AppLanguage.ENGLISH -> "Payment status"
    }
    val paymentDone: String = when (language) {
        AppLanguage.KOREAN -> "결제 완료"
        AppLanguage.ENGLISH -> "Payment done"
    }
    val autoPay: String = when (language) {
        AppLanguage.KOREAN -> "자동결제"
        AppLanguage.ENGLISH -> "Auto Pay"
    }
    val variable: String = when (language) {
        AppLanguage.KOREAN -> "변동"
        AppLanguage.ENGLISH -> "Variable"
    }
    val select: String = when (language) {
        AppLanguage.KOREAN -> "선택"
        AppLanguage.ENGLISH -> "Select"
    }
    val cancel: String = when (language) {
        AppLanguage.KOREAN -> "취소"
        AppLanguage.ENGLISH -> "Cancel"
    }
    val confirm: String = when (language) {
        AppLanguage.KOREAN -> "확인"
        AppLanguage.ENGLISH -> "Confirm"
    }
    val save: String = when (language) {
        AppLanguage.KOREAN -> "저장"
        AppLanguage.ENGLISH -> "Save"
    }
    val name: String = when (language) {
        AppLanguage.KOREAN -> "이름"
        AppLanguage.ENGLISH -> "Name"
    }
    val amount: String = when (language) {
        AppLanguage.KOREAN -> "금액"
        AppLanguage.ENGLISH -> "Amount"
    }
    val amountUndecided: String = when (language) {
        AppLanguage.KOREAN -> "금액 미정"
        AppLanguage.ENGLISH -> "Variable amount"
    }
    val category: String = when (language) {
        AppLanguage.KOREAN -> "카테고리"
        AppLanguage.ENGLISH -> "Category"
    }
    val customCategory: String = when (language) {
        AppLanguage.KOREAN -> "직접 입력 카테고리"
        AppLanguage.ENGLISH -> "Custom category"
    }
    val nextBillingDateLabel: String = when (language) {
        AppLanguage.KOREAN -> "다음 결제일"
        AppLanguage.ENGLISH -> "Next billing date"
    }
    val openCalendar: String = when (language) {
        AppLanguage.KOREAN -> "캘린더 열기"
        AppLanguage.ENGLISH -> "Open calendar"
    }
    val billingCycle: String = when (language) {
        AppLanguage.KOREAN -> "결제 주기"
        AppLanguage.ENGLISH -> "Billing cycle"
    }
    val billingCycleMonthly: String = when (language) {
        AppLanguage.KOREAN -> "매월"
        AppLanguage.ENGLISH -> "Monthly"
    }
    val billingCycleYearly: String = when (language) {
        AppLanguage.KOREAN -> "매년"
        AppLanguage.ENGLISH -> "Yearly"
    }
    val billingCycleCustom30: String = when (language) {
        AppLanguage.KOREAN -> "30일마다"
        AppLanguage.ENGLISH -> "Every 30 days"
    }
    val dateFormatHint: String = when (language) {
        AppLanguage.KOREAN -> "YYYY-MM-DD 형식"
        AppLanguage.ENGLISH -> "Use YYYY-MM-DD"
    }
    val pinned: String = when (language) {
        AppLanguage.KOREAN -> "고정"
        AppLanguage.ENGLISH -> "Pinned"
    }
    val autoPayEnabled: String = when (language) {
        AppLanguage.KOREAN -> "자동결제"
        AppLanguage.ENGLISH -> "Auto pay"
    }
    val notificationsEnabled: String = when (language) {
        AppLanguage.KOREAN -> "알림"
        AppLanguage.ENGLISH -> "Notifications"
    }
    val memo: String = when (language) {
        AppLanguage.KOREAN -> "메모"
        AppLanguage.ENGLISH -> "Memo"
    }
    val previousMonth: String = when (language) {
        AppLanguage.KOREAN -> "이전 달"
        AppLanguage.ENGLISH -> "Previous month"
    }
    val nextMonth: String = when (language) {
        AppLanguage.KOREAN -> "다음 달"
        AppLanguage.ENGLISH -> "Next month"
    }
    val currentMonth: String = when (language) {
        AppLanguage.KOREAN -> "이번 달"
        AppLanguage.ENGLISH -> "This month"
    }
    val pin: String = when (language) {
        AppLanguage.KOREAN -> "고정"
        AppLanguage.ENGLISH -> "Pin"
    }
    val unpin: String = when (language) {
        AppLanguage.KOREAN -> "고정 해제"
        AppLanguage.ENGLISH -> "Unpin"
    }
    val cancelPayment: String = when (language) {
        AppLanguage.KOREAN -> "결제 완료 취소"
        AppLanguage.ENGLISH -> "Cancel payment"
    }
    val deleteSelected: String = when (language) {
        AppLanguage.KOREAN -> "일괄 삭제"
        AppLanguage.ENGLISH -> "Delete"
    }
    val markSelectedPaid: String = when (language) {
        AppLanguage.KOREAN -> "결제 완료"
        AppLanguage.ENGLISH -> "Payment complete"
    }
    val cancelSelectedPayment: String = when (language) {
        AppLanguage.KOREAN -> "결제 취소"
        AppLanguage.ENGLISH -> "Cancel payment"
    }
    val archiveSelected: String = when (language) {
        AppLanguage.KOREAN -> "보관"
        AppLanguage.ENGLISH -> "Archive"
    }
    val changeSelectedDate: String = when (language) {
        AppLanguage.KOREAN -> "결제일 수정"
        AppLanguage.ENGLISH -> "Change date"
    }
    val editCustomOrder: String = when (language) {
        AppLanguage.KOREAN -> "순서 편집"
        AppLanguage.ENGLISH -> "Edit order"
    }
    val doneCustomOrder: String = when (language) {
        AppLanguage.KOREAN -> "편집 완료"
        AppLanguage.ENGLISH -> "Done editing"
    }
    val customOrderDescription: String = when (language) {
        AppLanguage.KOREAN -> "길게 눌러 드래그해서 보드 카드 순서를 바꾸세요."
        AppLanguage.ENGLISH -> "Long press and drag to reorder board cards."
    }
    val moveUp: String = when (language) {
        AppLanguage.KOREAN -> "위로 이동"
        AppLanguage.ENGLISH -> "Move up"
    }
    val moveDown: String = when (language) {
        AppLanguage.KOREAN -> "아래로 이동"
        AppLanguage.ENGLISH -> "Move down"
    }
    val invalidForm: String = when (language) {
        AppLanguage.KOREAN -> "입력값을 확인해 주세요."
        AppLanguage.ENGLISH -> "Please check the form values."
    }
    val errorTitle: String = when (language) {
        AppLanguage.KOREAN -> "오류"
        AppLanguage.ENGLISH -> "Error"
    }
    val unknownError: String = when (language) {
        AppLanguage.KOREAN -> "알 수 없는 오류가 발생했습니다."
        AppLanguage.ENGLISH -> "An unknown error occurred."
    }

    val archiveTitle: String = when (language) {
        AppLanguage.KOREAN -> "보관함"
        AppLanguage.ENGLISH -> "Archive"
    }
    val archiveSubtitle: String = when (language) {
        AppLanguage.KOREAN -> "보관한 정기 결제 항목을 모아두는 곳입니다. 필요한 항목은 언제든 다시 꺼낼 수 있습니다."
        AppLanguage.ENGLISH -> "This is where archived subscriptions are kept. You can restore any item whenever you need it."
    }
    val noArchivedSubscriptions: String = when (language) {
        AppLanguage.KOREAN -> "보관된 구독이 없습니다."
        AppLanguage.ENGLISH -> "No archived subscriptions."
    }
    val restore: String = when (language) {
        AppLanguage.KOREAN -> "복원"
        AppLanguage.ENGLISH -> "Restore"
    }
    val delete: String = when (language) {
        AppLanguage.KOREAN -> "삭제"
        AppLanguage.ENGLISH -> "Delete"
    }

    val settingsTitle: String = when (language) {
        AppLanguage.KOREAN -> "설정"
        AppLanguage.ENGLISH -> "Settings"
    }
    val settingsSubtitle: String = when (language) {
        AppLanguage.KOREAN -> "안드로이드는 먼저 iOS와 같은 설정 모델을 맞춥니다. 백업과 계정 흐름은 그다음 단계입니다."
        AppLanguage.ENGLISH -> "Android keeps the same preference model as iOS first. Backup and account flows come next."
    }
    val appearance: String = when (language) {
        AppLanguage.KOREAN -> "화면 모드"
        AppLanguage.ENGLISH -> "Appearance"
    }
    val languageLabel: String = when (language) {
        AppLanguage.KOREAN -> "언어"
        AppLanguage.ENGLISH -> "Language"
    }
    val initialScreen: String = when (language) {
        AppLanguage.KOREAN -> "초기 화면"
        AppLanguage.ENGLISH -> "Initial Screen"
    }
    val behavior: String = when (language) {
        AppLanguage.KOREAN -> "동작"
        AppLanguage.ENGLISH -> "Behavior"
    }
    val showBoardSearch: String = when (language) {
        AppLanguage.KOREAN -> "보드 검색 표시"
        AppLanguage.ENGLISH -> "Show board search"
    }
    val pushNotifications: String = when (language) {
        AppLanguage.KOREAN -> "푸시 알림"
        AppLanguage.ENGLISH -> "Push notifications"
    }
    val pushNotificationsCaption: String = when (language) {
        AppLanguage.KOREAN -> "결제 리마인더와 테스트 알림을 받으려면 시스템 알림 권한이 필요합니다."
        AppLanguage.ENGLISH -> "System notification permission is required for reminders and test notifications."
    }
    val notificationChannelName: String = when (language) {
        AppLanguage.KOREAN -> "PayBoard 리마인더"
        AppLanguage.ENGLISH -> "PayBoard Reminders"
    }
    val notificationChannelDescription: String = when (language) {
        AppLanguage.KOREAN -> "정기 결제 리마인더와 테스트 알림"
        AppLanguage.ENGLISH -> "Subscription reminders and test notifications"
    }
    val notificationReminderTitle: String = when (language) {
        AppLanguage.KOREAN -> "결제 예정 알림"
        AppLanguage.ENGLISH -> "Upcoming payment"
    }
    val notificationReminderBodyFormat: String = when (language) {
        AppLanguage.KOREAN -> "%s 결제가 곧 예정되어 있습니다."
        AppLanguage.ENGLISH -> "%s payment is due soon."
    }
    val notificationAutoPayBodyTodayFormat: String = when (language) {
        AppLanguage.KOREAN -> "%s 서비스가 오늘 자동이체 될 예정입니다."
        AppLanguage.ENGLISH -> "%s will be charged by auto pay today."
    }
    val notificationAutoPayBodyTomorrowFormat: String = when (language) {
        AppLanguage.KOREAN -> "%s 서비스가 내일 자동이체 될 예정입니다."
        AppLanguage.ENGLISH -> "%s will be charged by auto pay tomorrow."
    }
    val notificationAutoPayBodyDayAfterTomorrowFormat: String = when (language) {
        AppLanguage.KOREAN -> "%s 서비스가 이틀 후 자동이체 될 예정입니다."
        AppLanguage.ENGLISH -> "%s will be charged by auto pay in two days."
    }
    val notificationAutoPayBodyDefaultFormat: String = when (language) {
        AppLanguage.KOREAN -> "%s 서비스가 자동이체 될 예정입니다."
        AppLanguage.ENGLISH -> "%s will be charged by auto pay soon."
    }
    val reminderOptions: String = when (language) {
        AppLanguage.KOREAN -> "리마인더 옵션"
        AppLanguage.ENGLISH -> "Reminder Options"
    }
    val reminderTime: (Int, Int) -> String = { hour, minute ->
        when (language) {
            AppLanguage.KOREAN -> "리마인더 시간 ${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}"
            AppLanguage.ENGLISH -> "Reminder time ${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}"
        }
    }
    val allowNotifications: String = when (language) {
        AppLanguage.KOREAN -> "알림 허용"
        AppLanguage.ENGLISH -> "Allow notifications"
    }
    val openSystemSettings: String = when (language) {
        AppLanguage.KOREAN -> "시스템 설정 열기"
        AppLanguage.ENGLISH -> "Open system settings"
    }
    val notificationsPermissionMessage: String = when (language) {
        AppLanguage.KOREAN -> "알림 권한이 없어 테스트 리마인더를 보낼 수 없습니다."
        AppLanguage.ENGLISH -> "Notification permission is required to send a test reminder."
    }
    val notificationsSettingsMessage: String = when (language) {
        AppLanguage.KOREAN -> "시스템 설정에서 앱 알림이 꺼져 있습니다."
        AppLanguage.ENGLISH -> "App notifications are disabled in system settings."
    }
    val sendTestReminder: String = when (language) {
        AppLanguage.KOREAN -> "테스트 리마인더 보내기"
        AppLanguage.ENGLISH -> "Send test reminder"
    }
    val testReminderSent: String = when (language) {
        AppLanguage.KOREAN -> "테스트 리마인더를 보냈습니다."
        AppLanguage.ENGLISH -> "Test reminder sent."
    }
    val testReminderFailed: String = when (language) {
        AppLanguage.KOREAN -> "테스트 리마인더 전송에 실패했습니다."
        AppLanguage.ENGLISH -> "Failed to send test reminder."
    }
    val backup: String = when (language) {
        AppLanguage.KOREAN -> "클라우드 백업"
        AppLanguage.ENGLISH -> "Cloud Backup"
    }
    val backupNotConfigured: String = when (language) {
        AppLanguage.KOREAN -> "Supabase 설정값이 없어 백업 로그인을 사용할 수 없습니다."
        AppLanguage.ENGLISH -> "Supabase keys are missing, so backup sign-in is unavailable."
    }
    val signInWithKakao: String = when (language) {
        AppLanguage.KOREAN -> "카카오로 로그인"
        AppLanguage.ENGLISH -> "Sign in with Kakao"
    }
    val signOut: String = when (language) {
        AppLanguage.KOREAN -> "로그아웃"
        AppLanguage.ENGLISH -> "Sign out"
    }
    val connectedAccount: String = when (language) {
        AppLanguage.KOREAN -> "연결 계정"
        AppLanguage.ENGLISH -> "Connected account"
    }
    val backupSignInSuccess: String = when (language) {
        AppLanguage.KOREAN -> "백업 계정 연결이 완료되었습니다."
        AppLanguage.ENGLISH -> "Backup account connected."
    }
    val backupSignInFailed: String = when (language) {
        AppLanguage.KOREAN -> "로그인에 실패했습니다."
        AppLanguage.ENGLISH -> "Sign-in failed."
    }
    val backupSignOutSuccess: String = when (language) {
        AppLanguage.KOREAN -> "로그아웃되었습니다."
        AppLanguage.ENGLISH -> "Signed out successfully."
    }
    val backupSignOutFailed: String = when (language) {
        AppLanguage.KOREAN -> "로그아웃에 실패했습니다."
        AppLanguage.ENGLISH -> "Failed to sign out."
    }
    val backupLoading: String = when (language) {
        AppLanguage.KOREAN -> "백업 계정 상태를 확인하는 중..."
        AppLanguage.ENGLISH -> "Checking backup account state..."
    }
    val backupLatestAtEmpty: String = when (language) {
        AppLanguage.KOREAN -> "최근 백업 기록이 없습니다."
        AppLanguage.ENGLISH -> "No recent backup yet."
    }
    val backupUpload: String = when (language) {
        AppLanguage.KOREAN -> "지금 백업하기"
        AppLanguage.ENGLISH -> "Upload backup"
    }
    val backupRestore: String = when (language) {
        AppLanguage.KOREAN -> "최신 백업 복원"
        AppLanguage.ENGLISH -> "Restore latest backup"
    }
    val backupDeleteAccount: String = when (language) {
        AppLanguage.KOREAN -> "계정 삭제"
        AppLanguage.ENGLISH -> "Delete account"
    }
    val backupSyncInProgress: String = when (language) {
        AppLanguage.KOREAN -> "백업을 동기화하는 중..."
        AppLanguage.ENGLISH -> "Syncing backup..."
    }
    val backupDeleteAccountInProgress: String = when (language) {
        AppLanguage.KOREAN -> "계정을 삭제하는 중..."
        AppLanguage.ENGLISH -> "Deleting account..."
    }
    val backupSignInRestorePrompt: String = when (language) {
        AppLanguage.KOREAN -> "이전에 저장된 백업을 찾았습니다."
        AppLanguage.ENGLISH -> "A previous backup was found."
    }
    val backupSignInAutoBackupDone: String = when (language) {
        AppLanguage.KOREAN -> "기존 백업이 없어 현재 데이터를 바로 업로드했습니다."
        AppLanguage.ENGLISH -> "No backup was found, so current data was uploaded."
    }
    val backupSignInRestoreSkipped: String = when (language) {
        AppLanguage.KOREAN -> "기존 백업 복원을 건너뛰었습니다."
        AppLanguage.ENGLISH -> "Skipped restoring the previous backup."
    }
    val backupUploadSuccess: String = when (language) {
        AppLanguage.KOREAN -> "클라우드 백업이 완료되었습니다."
        AppLanguage.ENGLISH -> "Backup uploaded successfully."
    }
    val backupUploadFailed: String = when (language) {
        AppLanguage.KOREAN -> "클라우드 백업에 실패했습니다."
        AppLanguage.ENGLISH -> "Failed to upload backup."
    }
    val backupRestoreSuccess: String = when (language) {
        AppLanguage.KOREAN -> "최신 백업을 복원했습니다."
        AppLanguage.ENGLISH -> "Backup restored successfully."
    }
    val backupRestoreFailed: String = when (language) {
        AppLanguage.KOREAN -> "백업 복원에 실패했습니다."
        AppLanguage.ENGLISH -> "Failed to restore backup."
    }
    val backupRestoreEmpty: String = when (language) {
        AppLanguage.KOREAN -> "복원할 백업이 없습니다."
        AppLanguage.ENGLISH -> "No backup is available to restore."
    }
    val backupDeleteAccountServerNotConfigured: String = when (language) {
        AppLanguage.KOREAN -> "계정 삭제 서버 설정이 없어 계정을 삭제할 수 없습니다."
        AppLanguage.ENGLISH -> "Account deletion server is not configured."
    }
    val backupDeleteAccountSuccess: String = when (language) {
        AppLanguage.KOREAN -> "계정이 삭제되었습니다."
        AppLanguage.ENGLISH -> "Account deleted successfully."
    }
    val backupDeleteAccountFailed: String = when (language) {
        AppLanguage.KOREAN -> "계정 삭제에 실패했습니다."
        AppLanguage.ENGLISH -> "Failed to delete account."
    }
    val backupRestorePromptTitle: String = when (language) {
        AppLanguage.KOREAN -> "백업을 복원할까요?"
        AppLanguage.ENGLISH -> "Restore your backup?"
    }
    val backupRestorePromptMessage: String = when (language) {
        AppLanguage.KOREAN -> "이 계정에 저장된 최신 백업을 지금 기기에 덮어쓸 수 있습니다."
        AppLanguage.ENGLISH -> "You can restore the latest cloud backup for this account onto this device."
    }
    val backupRestorePromptSkip: String = when (language) {
        AppLanguage.KOREAN -> "건너뛰기"
        AppLanguage.ENGLISH -> "Skip"
    }
    val backupRestorePromptRestore: String = when (language) {
        AppLanguage.KOREAN -> "복원하기"
        AppLanguage.ENGLISH -> "Restore"
    }
    val backupRestoreConfirmTitle: String = when (language) {
        AppLanguage.KOREAN -> "최신 백업을 복원할까요?"
        AppLanguage.ENGLISH -> "Restore the latest backup?"
    }
    val backupRestoreConfirmMessage: String = when (language) {
        AppLanguage.KOREAN -> "현재 기기 데이터가 최신 클라우드 백업으로 교체됩니다."
        AppLanguage.ENGLISH -> "Current device data will be replaced with the latest cloud backup."
    }
    val backupRestoreConfirmAction: String = when (language) {
        AppLanguage.KOREAN -> "복원"
        AppLanguage.ENGLISH -> "Restore"
    }
    val backupDeleteAccountConfirmTitle: String = when (language) {
        AppLanguage.KOREAN -> "계정을 삭제할까요?"
        AppLanguage.ENGLISH -> "Delete your account?"
    }
    val backupDeleteAccountConfirmAction: String = when (language) {
        AppLanguage.KOREAN -> "계정 삭제"
        AppLanguage.ENGLISH -> "Delete account"
    }
    val deleteSingle: String = when (language) {
        AppLanguage.KOREAN -> "삭제"
        AppLanguage.ENGLISH -> "Delete"
    }

    fun backupLatestAt(value: String): String = when (language) {
        AppLanguage.KOREAN -> "최근 백업: $value"
        AppLanguage.ENGLISH -> "Last backup: $value"
    }

    fun backupDeleteAccountConfirmMessage(account: String?): String = when (language) {
        AppLanguage.KOREAN -> if (account.isNullOrBlank()) {
            "이 작업은 되돌릴 수 없습니다. 계정과 백업 데이터가 모두 삭제됩니다."
        } else {
            "$account 계정과 백업 데이터를 모두 삭제합니다. 이 작업은 되돌릴 수 없습니다."
        }
        AppLanguage.ENGLISH -> if (account.isNullOrBlank()) {
            "This will permanently delete your account and backup data."
        } else {
            "This will permanently delete $account and all backup data."
        }
    }

    fun appearanceLabel(appearance: AppAppearance): String = when (appearance) {
        AppAppearance.SYSTEM -> when (language) {
            AppLanguage.KOREAN -> "시스템"
            AppLanguage.ENGLISH -> "System"
        }
        AppAppearance.LIGHT -> when (language) {
            AppLanguage.KOREAN -> "라이트"
            AppLanguage.ENGLISH -> "Light"
        }
        AppAppearance.DARK -> when (language) {
            AppLanguage.KOREAN -> "다크"
            AppLanguage.ENGLISH -> "Dark"
        }
    }

    fun languageLabel(language: AppLanguage): String = when (language) {
        AppLanguage.KOREAN -> "한국어"
        AppLanguage.ENGLISH -> "English"
    }

    fun initialScreenLabel(screen: InitialScreen): String = when (screen) {
        InitialScreen.BOARD -> routeBoard
        InitialScreen.CALENDAR -> routeCalendar
    }

    fun reminderOptionLabel(option: ReminderOption): String = when (language) {
        AppLanguage.KOREAN -> when (option) {
            ReminderOption.ONE_DAY -> "1일 전"
            ReminderOption.THREE_DAYS -> "3일 전"
            ReminderOption.SEVEN_DAYS -> "7일 전"
        }
        AppLanguage.ENGLISH -> when (option) {
            ReminderOption.ONE_DAY -> "1 day before"
            ReminderOption.THREE_DAYS -> "3 days before"
            ReminderOption.SEVEN_DAYS -> "7 days before"
        }
    }

    fun categoryLabel(category: SubscriptionCategory): String = when (language) {
        AppLanguage.KOREAN -> when (category) {
            SubscriptionCategory.VIDEO -> "영상"
            SubscriptionCategory.MUSIC -> "음악"
            SubscriptionCategory.PRODUCTIVITY -> "생산성"
            SubscriptionCategory.CLOUD -> "클라우드"
            SubscriptionCategory.HOUSING -> "주거"
            SubscriptionCategory.SHOPPING -> "쇼핑"
            SubscriptionCategory.GAMING -> "게임"
            SubscriptionCategory.FINANCE -> "금융"
            SubscriptionCategory.EDUCATION -> "교육"
            SubscriptionCategory.HEALTH -> "건강"
            SubscriptionCategory.OTHER -> "기타"
        }
        AppLanguage.ENGLISH -> category.label
    }

    fun boardFilterLabel(label: String): String = when (language) {
        AppLanguage.KOREAN -> when (label) {
            "All" -> "전체"
            "This Week" -> "이번 주"
            "This Month" -> "이번 달"
            else -> label
        }
        AppLanguage.ENGLISH -> label
    }

    fun boardLayoutLabel(columnsCount: Int): String = when (columnsCount) {
        3 -> layoutSmall
        2 -> layoutNormal
        else -> layoutMax
    }

    fun archiveDateLabel(instant: Instant): String = when (language) {
        AppLanguage.KOREAN -> "${formatDate(instant)} 보관"
        AppLanguage.ENGLISH -> "Archived ${formatDate(instant)}"
    }

    fun selectedCount(count: Int): String = when (language) {
        AppLanguage.KOREAN -> "${count}개 선택됨"
        AppLanguage.ENGLISH -> "$count selected"
    }

    fun bulkDeleteConfirmMessage(count: Int): String = when (language) {
        AppLanguage.KOREAN -> "선택한 ${count}개의 구독을 삭제할까요?"
        AppLanguage.ENGLISH -> "Delete $count selected subscriptions?"
    }

    fun notificationReminderBody(subscriptionName: String): String =
        String.format(locale, notificationReminderBodyFormat, subscriptionName)

    fun notificationAutoPayBody(subscriptionName: String, daysBefore: Int): String {
        val format = when (daysBefore) {
            0 -> notificationAutoPayBodyTodayFormat
            1 -> notificationAutoPayBodyTomorrowFormat
            2 -> notificationAutoPayBodyDayAfterTomorrowFormat
            else -> notificationAutoPayBodyDefaultFormat
        }
        return String.format(locale, format, subscriptionName)
    }

    fun formatCurrency(
        amount: BigDecimal,
        currencyCode: String,
        isAmountUndecided: Boolean = false,
    ): String {
        if (isAmountUndecided) return variable
        if (currencyCode.uppercase() == "KRW") {
            val formatter = NumberFormat.getNumberInstance(locale).apply {
                maximumFractionDigits = 0
            }
            val suffix = if (language == AppLanguage.KOREAN) "원" else " KRW"
            return formatter.format(amount) + suffix
        }
        val formatter = NumberFormat.getCurrencyInstance(locale).apply {
            this.currency = java.util.Currency.getInstance(currencyCode.uppercase())
            maximumFractionDigits = 0
        }
        return formatter.format(amount)
    }

    fun formatDate(instant: Instant): String = DateTimeFormatter.ofPattern(
        if (language == AppLanguage.KOREAN) "yyyy. M. d." else "MMM d, yyyy",
        locale,
    )
        .withZone(ZoneId.systemDefault())
        .format(instant)

    fun formatShortDate(instant: Instant): String = DateTimeFormatter.ofPattern(
        if (language == AppLanguage.KOREAN) "M월 d일" else "MMM d",
        locale,
    )
        .withZone(ZoneId.systemDefault())
        .format(instant)

    fun monthTitle(reference: Instant = Instant.now()): String = DateTimeFormatter.ofPattern(
        if (language == AppLanguage.KOREAN) "M월" else "MMMM",
        locale,
    )
        .withZone(ZoneId.systemDefault())
        .format(reference)

    fun monthYearTitle(yearMonth: YearMonth): String = DateTimeFormatter.ofPattern(
        if (language == AppLanguage.KOREAN) "yyyy년 M월" else "MMMM yyyy",
        locale,
    ).format(yearMonth.atDay(1))

    fun monthOptionLabel(yearMonth: YearMonth): String = DateTimeFormatter.ofPattern(
        if (language == AppLanguage.KOREAN) "yyyy년 M월" else "MMM yyyy",
        locale,
    ).format(yearMonth.atDay(1))

    fun parseIsoLocalDate(rawValue: String): LocalDate? = runCatching {
        LocalDate.parse(rawValue.trim())
    }.getOrNull()

    fun billingCycleLabel(cycle: kr.co.cdd.payboard.core.domain.model.BillingCycle): String = when (cycle) {
        kr.co.cdd.payboard.core.domain.model.BillingCycle.Monthly -> billingCycleMonthly
        kr.co.cdd.payboard.core.domain.model.BillingCycle.Yearly -> billingCycleYearly
        is kr.co.cdd.payboard.core.domain.model.BillingCycle.CustomDays -> when (language) {
            AppLanguage.KOREAN -> "${cycle.days}일마다"
            AppLanguage.ENGLISH -> "Every ${cycle.days} days"
        }
    }
}

val LocalPayBoardStrings = staticCompositionLocalOf { PayBoardStrings(AppLanguage.KOREAN) }

@Composable
fun rememberPayBoardStrings(language: AppLanguage): PayBoardStrings = remember(language) {
    PayBoardStrings(language)
}
