# PayBoard

PayBoard는 흩어져 있는 정기결제와 고정지출을 한 화면에서 관리할 수 있게 만든 iOS 앱입니다.  
이번 달에 얼마가 빠져나가는지, 어떤 서비스가 곧 결제되는지, 자동이체 항목이 제대로 넘어갔는지를 보드와 캘린더 기준으로 빠르게 확인하는 데 초점을 맞추고 있습니다.

[App Store](https://apps.apple.com/us/app/%ED%8E%98%EC%9D%B4%EB%B3%B4%EB%93%9C/id6759862036)  
[Instagram](https://www.instagram.com/payboard.app/)

## What PayBoard Does

- 정기결제 항목을 보드 형태로 모아 보고, 이번 달 결제 합계와 카테고리별 지출을 바로 확인할 수 있습니다.
- 월간 캘린더에서 날짜별 결제 예정 항목을 확인하고, 특정 날짜 기준으로 결제 흐름을 볼 수 있습니다.
- 서비스명, 카테고리, 금액, 결제 주기, 다음 결제일, 메모, 아이콘, 자동이체 여부까지 세부적으로 관리할 수 있습니다.
- 검색, 필터, 정렬, 커스텀 순서 편집, 상단 고정, 일괄 완료/보관/삭제/결제일 변경으로 항목이 많아져도 정리가 가능합니다.
- 결제 완료 처리 시 다음 청구일이 자동으로 갱신되고, 자동이체 항목은 날짜가 지나면 자동 반영됩니다.
- 3일 전, 1일 전, 당일 리마인드 알림과 테스트 알림을 지원합니다.
- Apple 로그인 또는 Kakao 로그인을 통한 클라우드 백업/복원 기능을 제공합니다.
- 보관함과 홈 화면 위젯으로 자주 보는 결제 정보를 더 가볍게 확인할 수 있습니다.
- 한국어/영어, 라이트/다크 모드, 초기 화면, 검색창 노출 여부 등 사용 환경을 직접 조정할 수 있습니다.

## App Structure

- `보드`: 결제일이 가까운 항목을 빠르게 훑고, 월간 지출 요약을 보는 기본 화면
- `캘린더`: 날짜별 결제 일정을 확인하는 월간 일정 화면
- `보관함`: 잠시 숨긴 항목을 다시 복원하는 공간
- `설정`: 알림, 백업, 언어, 화면 모드, 초기 화면을 조정하는 영역

## Repository

이 저장소는 PayBoard 모노레포입니다.

- `ios/`: 현재 운영 중인 iOS 앱, Swift 패키지 모듈, Xcode 프로젝트, 위젯, Supabase 연동 스크립트
- `android/`: Android 앱 작업 공간

## iOS Development

Requirements:

- Xcode
- Swift 6.2 toolchain
- iOS 17+

Bootstrap:

```bash
cd ios
./scripts/bootstrap-macos.sh
```

Build:

```bash
cd ios
swift build
```

Test:

```bash
cd ios
swift test
```

Xcode project:

- `ios/PayBoardiOS.xcodeproj`

Supabase example config:

- `ios/PayboardConfig.example.xcconfig`
