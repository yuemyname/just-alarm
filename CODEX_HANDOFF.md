# justalarm — Codex 작업 인수인계

## 시작하기

이 문서가 있는 저장소 루트를 Codex 프로젝트로 열고 `AGENTS.md`부터 읽으세요. Xcode 프로젝트와 실행 대상은 `justalarm`, 앱 표시 이름은 `just alarm`입니다. iOS 26 이상, SwiftUI + AlarmKit 기반이며 서버나 외부 패키지는 없습니다.

- 이 Mac의 Git 작업 폴더: `/Users/yue/Documents/Codex/2026-10-12/new-chat/work/justalarm`
- `outputs/justalarm`과 ZIP은 배포용 사본입니다. Git 작업을 이어갈 때는 위 작업 폴더를 여세요. 다른 Mac에서는 아래 GitHub 저장소를 clone하세요.
- GitHub: https://github.com/yuemyname/just-alarm
- Xcode: `justalarm.xcodeproj`
- Swift 소스와 모듈: `JustAlarm`
- 기존 설치 호환성: Bundle Identifier `com.ccrtpie.jikim` 및 내부 `Application Support/Jikim/alarms.json` 경로 유지
- 현재 개발 팀 설정은 보존하고, 다른 계정으로 실행할 때만 사용자와 확인

## 사용자의 필수 선호

- 모든 앱에 한국어·영어 언어 설정을 포함하고 선택을 저장합니다.
- 이 앱은 `AppLanguage.swift`와 `@AppStorage`로 언어를 관리합니다.
- 새 UI 문구는 `ko.lproj/Localizable.strings`, `en.lproj/Localizable.strings`에 모두 추가합니다.
- 사용자가 입력한 알람 이름은 번역하거나 덮어쓰지 않습니다.
- 아이폰 기본 앱처럼 간결하게 유지합니다.

## 현재 기능과 주의점

- 알람 추가·편집·삭제, 요일 반복, 켜기/끄기, 이름·시간 검색, 검색 결과 일괄 작업
- 왼쪽 스와이프 삭제, 오른쪽 스와이프 반복 알람 다음 한 번 건너뛰기/취소
- 건너뛰기는 이후 8회 예약과 예약 기한 표시 방식입니다. 건너뛸 시간이 지난 뒤 앱을 열면 무기한 반복 예약으로 복원합니다. 이 제약을 감추거나 무기한 백그라운드 갱신을 약속하지 마세요.
- AlarmKit 예약 교체 실패 시 복구 로직이 있습니다. 수정 시 데이터·예약을 먼저 지워 잃어버리지 않도록 주의하세요.
- 기본 시계 앱의 Siri 명령을 가로채는 기능이나 전체 끄기 보호 기능은 없습니다.

## 이번 이미지 변경

- `Design/Bird.png`: 사용자 제공 원본 PNG, 투명 배경, 변경 없이 보존
- `Design/GenerateAppIcon.swift`: 원본을 흰 배경 위에 배치해 불투명 1024×1024 앱 아이콘 생성
- `JustAlarm/Assets.xcassets/AppIcon.appiconset/AppIcon.png`: 실제 배포 아이콘
- `JustAlarm/bird.gif`: 사용자 제공 GIF 원본, 앱 리소스로 포함
- `JustAlarm/StartupView.swift`: 시작 시 GIF를 한 번 재생하는 화면
- 정적 시스템 Launch Screen은 흰 배경입니다. 시스템 Launch Screen 자체에 GIF를 넣지 않습니다.
- 알람 목록을 동시에 구성하며 GIF를 표시합니다. 탭 또는 VoiceOver 동작으로 바로 건너뛸 수 있습니다.
- 동작 줄이기가 켜져 있거나 GIF를 읽지 못하면 바로 목록으로 넘어갑니다.
- 단순히 앱을 백그라운드에서 다시 열 때는 시작 애니메이션을 반복하지 않습니다.
- 이것은 시작 연출이며 실제 네트워크/알람 로딩 진행률을 뜻하지 않습니다.

## 검증 명령

```sh
swift Design/GenerateAppIcon.swift
bash Tests/run-tests.sh
xcodebuild -project justalarm.xcodeproj -scheme justalarm -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project justalarm.xcodeproj -scheme justalarm -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Xcode 프로젝트는 파일을 명시적으로 등록합니다. 새 Swift 파일은 Sources, GIF 같은 리소스는 Resources 빌드 단계에 추가해야 합니다. 실기기 알람 울림, 권한 및 Siri 동작은 별도 검증이 필요합니다. 자동 테스트나 빌드 성공만으로 실기기 동작을 확인했다고 보고하지 마세요.

## Codex에 붙여넣을 프롬프트

```text
이 저장소의 justalarm iOS 앱 작업을 이어서 해줘.
먼저 AGENTS.md, CODEX_HANDOFF.md, README.md와 git 상태를 확인해줘.
프로젝트/실행 대상은 justalarm, Swift 소스는 JustAlarm 폴더야.

현재 앱 아이콘은 Design/Bird.png 원본을 기반으로 하고, 시작 화면은 JustAlarm/bird.gif를 한 번 재생해.
원본 캐릭터를 임의로 다시 그리거나 픽셀 아트로 바꾸지 말아줘.
시작 화면에서 탭으로 건너뛰기, 동작 줄이기, GIF 실패 시 즉시 진입이 유지되도록 해줘.
한국어·영어 설정과 기존 알람 데이터, Bundle Identifier는 유지해줘.

이후 요청하는 변경을 구현하고 관련 테스트와 iOS 빌드를 확인해줘.
완료 시 변경 내용과 실제 확인한 범위, 실기기에서 남은 확인 사항을 간단히 알려줘.
```

## 이번 변경의 검증 기록

- 아이폰 및 시뮬레이터 빌드 성공
- 기존 알람·검색·일괄 작업·편집 복구·건너뛰기·한국어/영어 테스트 통과
- 시뮬레이터에서 GIF 시작 화면과 재생 종료 후 알람 목록 표시 확인
- 탭/VoiceOver 건너뛰기, 동작 줄이기 및 실기기 울림은 별도 수동 확인 필요
