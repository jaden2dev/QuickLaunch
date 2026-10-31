# Contributing

버그 제보와 개선 제안을 환영합니다. 이 저장소의 Issues에 macOS 버전, Mac 종류(Apple Silicon / Intel), 재현 방법, 기대한 결과와 실제 결과를 남겨 주세요. 스크린샷에서는 개인 정보를 가려 주세요.

## 개발

1. 저장소를 fork하고 변경용 브랜치를 만듭니다.
2. `Package.swift`를 Xcode에서 열거나 `swift build`로 빌드합니다.
3. `swift test`와 `bash scripts/build-app.sh`를 실행합니다.
4. 변경 내용과 검증 결과를 적어 pull request를 엽니다.

설정 저장 형식을 바꿀 때는 기존 사용자의 앱 연결을 유지하는 이관 테스트를 포함해 주세요. 전역 단축키와 창 표시 동작은 실제 macOS 로그인 세션에서도 확인해야 합니다.

코드와 기여분은 [MIT License](LICENSE)를 따릅니다.
