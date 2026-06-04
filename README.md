# MagicSquare_xx

**MagicSquare_1004** — 4×4 마방진(합 **34**, 1~16, 빈 칸 **2개**) ECB 실습 프로젝트.  
**Mom Test STEP 1**으로 문제를 정의했고, **세션 3**에서는 손 풀이에서 드러난 **판정·재검산 비용**을 **Rule · Command · Test Loop**로 코드화합니다.

> 소비자용 학습 앱이 아닙니다. 슬라이드 **4.1 Magic Square** 기준 **Entity–Control–Boundary** 설계·검증 과제입니다.

---

## 한눈에 보기

| | |
|---|---|
| **진짜 문제** | 행·열 차이로 후보를 넣고 손으로 확인할 때, **대각선 포함 판정이 늦게** 드러나 **첫 칸부터 전체 재검산**을 반복해도 맞지 않아 **확인 비용만 쌓인 뒤 중단** |
| **세션 3 목표** | 10선·1~16 제약을 **넣기 전·직후** 한 번에 판정 (`SquareValidator` + Command + 테스트) |
| **하지 않음** | 자동 풀이, GUI, AI 힌트, 정답 두 칸 자동 출력 |
| **Mom Test 점수** | **9 / 10** ([보완 질문](#open-questions) 참고) |

---

## 도메인

| 항목 | 정의 |
|------|------|
| 격자 | 4×4 |
| 값 | 1~16 (`0` = 빈 칸) |
| 마법 합 | **34** |
| **10선** | 행 4 + 열 4 + 대각선 2 |
| 과제 | 빈 칸 **2개** 채우기 (나머지 고정) |

**슬라이드 예시 격자** (`docs/PRD.md` §9.1)

```
16  3  2  13
 5 10 11   0
 9  6  0  12
 4 15 14   1
```

---

## Mom Test (STEP 1) — 확정 내용

### 페르소나

4×4 격자, 빈 칸 2개(0), 1~16, 합 34를 맞추는 **학습자** (손 풀이, 차이 확인 → 후보 약 3개 시도).

### 증거 3줄 (인용)

1. "1일전이었고 될법한 숫자를 한번 넣어서 답과 얼마나 차이가 나는지 확인했어"
2. "대각선이 안 맞았을 때 … **첫번째부터 다시 확인 함** … **3번**" → "**안 맞아서 포기했어**" / "**그대로 두었어**" / "**다시 보지 않음**"
3. "**10분**" / "**5분** 다 확인 했어" / "**다 계산해야해서 시간이 오래 걸렸어**" / "**손으로 했어**"

### 표면 문제 (잘못된 정의 — 만들지 않음)

- 4×4 마방진 **자동 풀이 프로그램**
- 빈 칸 2개 **Solver**
- **Validator 앱** / **GUI**로 10분·5분만 줄이기

전체 인터뷰 기록: [`Prompt/01.Prompt.md`](Prompt/01.Prompt.md)

---

## 세션 3 — 구현 범위

### 8계층 (이번에만)

| 계층 | 내용 |
|------|------|
| **Rule** | 합 34, 1~16, 중복, 빈 칸 2개, 10선 |
| **Command** | `validate_grid`, `validate_after_place` |
| **(Skill)** | *(선택)* 후보 조합 사전 검증 |
| **Test Loop** | 실패 ≥3, 대각-only FAIL, 통과 격자 1건 |

### ECB

```
Entity     MagicSquare, Cell, SolveResult
Control    SquareValidator (+ Command)     ← 세션 3
             MissingFinder, Solver         ← 이후
Boundary   GridUI, InputHandler, ResultDisplay   ← 세션 3 제외
```

### 성공 지표 (PRD §7)

| ID | 내용 | Mom Test 연결 |
|----|------|----------------|
| M1 | 대각-only FAIL 테스트 | 대각 불일치 → 3번 재확인 |
| M2 | `validate_grid` 1회로 10선 | 10분+5분 손 확인 |
| M3 | 실패 조건 ≥3, 테스트로 원인 식별 | 포기·미재방문 |

### 실패 조건 (연습 ≥3)

1. 10선 중 **합 ≠ 34**
2. **1~16 밖** 또는 **중복**
3. **빈 칸 ≠ 2**
4. **행·열만 맞고 대각 불일치** (인터뷰 핵심)

---

## 문서 맵

| 경로 | 용도 |
|------|------|
| [`Report/01.MagicSquare_ProblemDefinition_Report.md`](Report/01.MagicSquare_ProblemDefinition_Report.md) | Mom Test·진짜/표면 문제·증거·실패 조건·채점 |
| [`docs/PRD.md`](docs/PRD.md) | R-G-I-O, Rule/Command 요구사항, 픽스처, NFR |
| [`Prompt/01.Prompt.md`](Prompt/01.Prompt.md) | STEP 1 인터뷰·워크북·질문 10개 전체 export |

---

## 프로젝트 구조

```
MagicSquare_xx/
├── README.md                 ← 이 파일
├── docs/
│   └── PRD.md
├── Report/
│   └── 01.MagicSquare_ProblemDefinition_Report.md
└── Prompt/
    └── 01.Prompt.md          ← Mom Test 대화 기록
```

*(소스·테스트 디렉터리는 세션 3 구현 시 추가 예정)*

---

## 진행 상태

- [x] Mom Test STEP 1 (인터뷰 · 워크북 · 질문 10개)
- [x] Problem Definition Report (`Report/`)
- [x] PRD v0.1 (`docs/`)
- [x] 인터뷰 export (`Prompt/`)
- [ ] Rule / Command 구현
- [ ] Test Loop (예: pytest)
- [ ] Entity · Boundary · Solver (이후 세션)

---

## Open Questions

1. **"답과 차이"** — 목표 합 34인지, 정답 격자인지 (증거 1 보강)
2. **5분 확인** 시 10선 **전부** vs **대각만 나중** ([채점 보완 질문](Report/01.MagicSquare_ProblemDefinition_Report.md#6-mom-test-evidence-quoted))

---

## 다음 단계 (권장)

1. 슬라이드 격자로 **대각-only FAIL** 테스트 1건 작성 (Red)
2. `SquareValidator` + `validate_grid` 구현 (Green)
3. 실패 조건 3가지 이상을 **테스트 이름**으로 고정 (Refactor)

---

## 참고

- **프로젝트 코드명:** MagicSquare_1004 / 저장소 폴더: `MagicSquare_xx`
- **설계 패턴:** ECB (Entity–Control–Boundary)
- **문제 탐색:** Rob Fitzpatrick, *The Mom Test*
