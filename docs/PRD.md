# MagicSquare_1004 — PRD (Session 3)

**문서:** `docs/PRD.md`  
**버전:** 0.1 (초안)  
**근거:** Mom Test STEP 1 + Problem Definition Report

---

## 1. Topic (One Sentence)

4×4·빈 칸 2개·합 34 조건에서, **후보를 넣기 전·넣은 직후**에 **10선(행4+열4+대각2)·1~16 제약을 한 번에 판정**해, 손 풀이 시 **"대각선에서 틀림 → 첫 칸부터 전부 다시 → 포기"**로 이어지는 **확인 비용·재검산 루프**를 **Rule·Command·Test Loop**로 먼저 걸러 낸다.

---

## 2. Problem Statement

### 2.1 진짜 문제

행·열 차이로 후보를 골라 칸에 넣고 손으로 다시 계산해 확인하는 과정에서, 대각선까지 포함한 판정이 늦게 드러나 첫 칸부터 전부 다시 검산을 여러 번 반복해도 맞는 조합에 도달하지 못해, 확인 비용만 쌓인 뒤 미완료로 중단한다.

### 2.2 표면 문제 (Out of Scope)

| Out of Scope | 이유 |
|--------------|------|
| 자동 풀이 / Solver 프로그램 | 후보 시도는 이미 함; 막힘은 채우기가 아닌 판정 |
| Validator·GUI 앱 | 실제 행동은 손만; 포기 후 재방문 없음 |
| UX·게임화·AI 힌트 | 증거는 분·재검산 횟수 |
| 정답 두 칸 자동 출력 | 세션 3 목표는 판정·실패 조건 |

---

## 3. Persona

**Primary:** 4×4 격자, 빈 칸 2개(0), 1~16, 합 34를 맞추는 학습자 (손 풀이, 차이·후보 3개 시도)

---

## 4. R-G-I-O

| | Description |
|---|-------------|
| **Role** | 학습자의 손 검산·재검산을 대신 **제약 위반을 즉시 판정**하는 Control (`SquareValidator` 등) |
| **Goal** | 행·열만 맞는 조합이 **대각·전체 제약에서 늦게 깨지는** 패턴을 **넣기 전·직후**에 차단; **첫 칸부터 3회 재검산 후 포기** 루프를 테스트로 재현 |
| **Input** | `int[4][4]` (0=empty), 빈 칸 2개, target sum 34 |
| **Output** | `Pass \| Fail` + `FailureReason` (row \| col \| diagonal \| range \| duplicate \| empty_count) |

---

## 5. Functional Requirements (Session 3)

### 5.1 Rule

- R1: 각 **행** 합 = 34 (완성된 행만 또는 부분 허용 정책 명시)
- R2: 각 **열** 합 = 34
- R3: **대각선 2개** 합 = 34
- R4: 값 ∈ {1..16}, **중복 없음** (0 제외)
- R5: **빈 칸(0) 정확히 2개**

### 5.2 Command

- C1: `validate_grid(grid) -> ValidationResult`
- C2: `validate_after_place(grid, row, col, value) -> ValidationResult`

### 5.3 (Optional) Skill

- S1: `check_candidates(grid, candidates[]) -> ValidationResult[]` — 행·열만 보고 넣기 **전** 10선 일괄 검사

### 5.4 Test Loop

- T1: Red — 대각-only FAIL fixture 1건
- T2: Green — Rule/Command 구현
- T3: Refactor — 실패 조건 ≥3 명명·문서화
- T4: Regression — 통과 격자 1건 (3개월 전 성공 유형 대응)

---

## 6. Non-Functional Requirements

- **재현성:** 동일 격자 입력 → 동일 Pass/Fail (손 3회 재검산과 동일 판정)
- **비용:** 1회 검증 << 손 10분+5분 (개발 환경 기준 ms 단위)
- **테스트 우선:** UI 없이 CLI/단위 테스트만으로 성공 기준 충족

---

## 7. Success Metrics

| ID | Metric | Mom Test Evidence |
|----|--------|-------------------|
| M1 | 대각-only FAIL 테스트 통과 | 대각선 불일치 → 3번 재확인 |
| M2 | `validate_grid` 1회 호출로 10선 결과 | 10분+5분 손 확인 |
| M3 | 실패 조건 ≥3 + 테스트 이름으로 원인 식별 | 포기·그대로 둠·다시 안 봄 |

---

## 8. ECB Mapping

| Layer | Session 3 | Later |
|-------|-----------|-------|
| Entity | `MagicSquare`, `Cell`, `SolveResult` | — |
| Control | `SquareValidator`, Command | `MissingFinder`, `Solver` |
| Boundary | — | `GridUI`, `InputHandler`, `ResultDisplay` |

---

## 9. Test Fixtures (Suggested)

### 9.1 Slide Example (partial)

```
16  3  2  13
 5 10 11   0
 9  6  0  12
 4 15 14   1
```

### 9.2 Diagonal-only FAIL (synthetic)

- 행·열 후보만 맞춘 뒤 **대각 합 ≠ 34** 인 조합 — Validator must FAIL(diagonal)

---

## 10. Open Questions

1. "답과 차이" — 34 합 vs 정답 격자 중 무엇을 기준으로 했는지 (증거 1 보강)
2. 5분 확인 시 **10선 전부** vs **대각만 나중** (채점 보완 질문)

---

## 11. Document Index

- `Report/01.MagicSquare_ProblemDefinition_Report.md` — Mom Test·문제 정의
- `docs/PRD.md` — 본 문서
