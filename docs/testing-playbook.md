# 테스트 플레이북

`CLAUDE.md` 에서 분리한 참조 문서. **Phase 종료 시**, 또는 아래 증상이 나타났을 때 읽는다.

- 테스트가 느리거나 CI에서만 간헐 실패 → 「증상」 섹션
- Phase/Sprint 종료 → 「약한 테스트 5유형 체크리스트」
- 새 타입을 설계할 때 → 「테스터블 코드 체크리스트」

---

# 테스트 진단·감사 플레이북

**테스트도 Tidy First 대상.** AI 생성 테스트에는 tautology/change detection/flaky가 섞인다.
개인 프로젝트 두 개의 단위 테스트 579개를 5유형 체크리스트로 훑어, 11개를 제거하고 1개를 바로잡았다(약 2%).
표본이 작고 한 사람이 같은 방식으로 만든 코드라 일반화할 수치는 아니지만, 0은 아니다.

## Phase/Sprint 종료 시 반드시

1. **테스트 품질 감사** 1시간
2. 우선순위: **flaky > tautology > 중복 > change detection**
3. 약한 테스트는 삭제·재작성하고 `[structural]` 커밋 후보로 묶는다
4. 삭제보다 **behavior 검증으로 재작성**이 나을 때도

## 약한 테스트 5유형 체크리스트

1. **Initializer tautology**: `T(a: 1).a == 1` — Swift memberwise init 테스트
2. **Literal array count**: 배열 만들고 `count == N`
3. **Self-referential constant**: `T.key == "key"`
4. **Auto-generated Equatable**: 단순 struct `a == b` 검증
5. **Factory self-check**: Factory가 세팅한 값 재확인

## 증상: 테스트가 느리다 / CI에서만 간헐 실패한다

`Task.sleep(ms:N)` 기반 테스트는 **brittle**. CI flaky 유발.
→ **Continuation gate** (AsyncStream, CheckedContinuation) 패턴으로 전환.

스캔:
```bash
grep -rn "Task.sleep\|Thread.sleep" KakaoImageSearchTests/
```

---

# 테스터블 코드 체크리스트

테스터블한 프로덕션 코드를 위한 6가지 원칙. 좋은 설계 자체이며, 의존성이 명확하고 로직이 분리된 코드는 테스트가 자연스럽게 따라온다.

| 원칙 | 핵심 질문 |
|------|----------|
| 의존성 주입 | 이 객체가 의존성을 직접 생성하고 있지 않은가? |
| 사이드 이펙트 분리 | 메서드에서 순수한 계산과 외부 호출이 섞여 있지 않은가? |
| 숨은 입력 제거 | 싱글톤, Date(), UserDefaults에 직접 접근하고 있지 않은가? |
| 인터페이스 완결 | 하나의 목표를 위해 여러 메서드를 순서대로 호출해야 하지 않은가? |
| 프레임워크 격리 | 비즈니스 로직에 UIKit, CoreLocation 등이 침투해 있지 않은가? |
| 프로토콜 경계 | 변경될 수 있는 외부 의존성 앞에 교체 가능한 경계가 있는가? |

출처: https://glassgow.tistory.com/57
