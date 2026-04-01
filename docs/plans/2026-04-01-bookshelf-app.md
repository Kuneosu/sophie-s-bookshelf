# 📚 Bookshelf — 독서 기록 앱 구현 계획서

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** 맥/안드로이드 크로스플랫폼 독서 기록 앱. 편리한 UX + 예쁜 UI 최우선.

**타겟 사용자:** 권수 (1인 사용)

---

## 📋 요구사항 정리

### 필수 기능
1. **책 검색 & 등록** — API로 책 검색 → 선택하면 제목/저자/출판사/표지 자동 입력
2. **독서 상태 관리** — `읽고 싶은` → `읽는 중` → `완독` → `중단` 등 상태 전환
3. **내 서재 목록** — 등록한 책들을 상태별/전체로 조회
4. **편리한 UX** — 최소 탭으로 책 등록, 상태 변경은 스와이프/원탭
5. **예쁜 UI** — 책 표지 중심 레이아웃, 깔끔한 디자인

### 불필요한 기능 (YAGNI)
- ❌ 페이지 수 기록 / 독서 진행률
- ❌ 소셜 기능 / 공유
- ❌ 독서 타이머
- ❌ 클라우드 동기화 (1인 사용)
- ❌ 회원가입/로그인

---

## 🏗 기술 스택 결정

### 프레임워크: **Compose Multiplatform (KMP)**

| 선택지 | 장점 | 단점 |
|--------|------|------|
| **Compose Multiplatform** ✅ | Kotlin 기반 (Android 개발자에게 친숙), 단일 코드베이스로 Android+macOS, JetBrains 공식 지원 | macOS 지원이 Flutter 대비 덜 성숙 |
| Flutter | 크로스플랫폼 생태계 성숙, 참고 레포 많음 (openreads 등) | Dart 언어 별도 학습 필요 |

**선택 이유:** 권수가 Android 개발자 → Kotlin이 자연스러움. Compose는 이미 Android에서 표준. 단일 언어로 전체 앱 작성 가능.

### 책 검색 API: **카카오 도서 검색 API** (메인) + **Google Books API** (보조)

| API | 한국 도서 | 해외 도서 | 무료 한도 | 메타데이터 |
|-----|----------|----------|----------|-----------|
| **카카오** ✅ (메인) | ★★★★★ | ★★☆ | 10만/월 | 제목, 저자, 출판사, 표지, ISBN, 설명 |
| **Google Books** (보조) | ★★☆ | ★★★★★ | 1,000/일 | 제목, 저자, 출판사, 표지, 페이지수, 카테고리 |
| 알라딘 | ★★★★★ | ★★☆ | ~5,000/일 | 가장 풍부 (페이지수, 카테고리, 목차) |
| 네이버 | ★★★★★ | ★★☆ | 25,000/일 | 기본적 |

**선택 이유:** 개인 앱이므로 카카오 10만/월이면 충분. API 키 발급이 가장 쉽고, 한국 도서 커버리지 우수. 해외 서적은 Google Books로 폴백.

### 로컬 DB: **Room (KMP)**

Kotlin Multiplatform에서 Room 사용 가능 (2024년부터 KMP 지원). Android 개발자에게 가장 친숙한 ORM.

### 이미지 로딩: **Coil 3** (KMP 지원)

### DI: **Koin** (KMP 친화적, 설정 간단)

### 참고 레포

| 레포 | 참고 포인트 |
|------|-----------|
| [openreads/openreads](https://github.com/openreads/openreads) | 기능/UX 플로우, 데이터 모델, 상태 관리 패턴 |
| [vipulyaara/Kafka](https://github.com/vipulyaara/Kafka) | Jetpack Compose UI 패턴, 책 표지 중심 레이아웃 |
| [JetBrains/compose-multiplatform](https://github.com/JetBrains/compose-multiplatform) | KMP 프로젝트 구조, 공식 템플릿 |

---

## 📐 아키텍처

```
┌─────────────────────────────────────────────┐
│                    UI Layer                  │
│         Compose Multiplatform Screens        │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐ │
│  │ 내 서재  │ │ 책 검색  │ │  책 상세     │ │
│  │ (홈)     │ │          │ │              │ │
│  └──────────┘ └──────────┘ └──────────────┘ │
├─────────────────────────────────────────────┤
│               ViewModel Layer               │
│     StateFlow + sealed class UiState        │
├─────────────────────────────────────────────┤
│              Repository Layer               │
│  ┌─────────────────┐ ┌───────────────────┐  │
│  │ BookRepository   │ │ SearchRepository  │  │
│  │ (Room DB CRUD)   │ │ (API 호출)        │  │
│  └─────────────────┘ └───────────────────┘  │
├─────────────────────────────────────────────┤
│               Data Layer                    │
│  ┌──────────┐ ┌───────────┐ ┌────────────┐ │
│  │ Room DB  │ │ Kakao API │ │ Google API │ │
│  └──────────┘ └───────────┘ └────────────┘ │
└─────────────────────────────────────────────┘
```

### 프로젝트 모듈 구조

```
bookshelf/
├── composeApp/               # Compose Multiplatform 공유 코드
│   └── src/
│       ├── commonMain/       # 공유 코드 (95%+)
│       │   └── kotlin/com/kuneosu/bookshelf/
│       │       ├── App.kt
│       │       ├── di/                  # Koin 모듈
│       │       ├── data/
│       │       │   ├── local/           # Room DB, Entity, DAO
│       │       │   ├── remote/          # API clients (Ktor)
│       │       │   └── repository/      # Repository impl
│       │       ├── domain/
│       │       │   └── model/           # Book, ReadingStatus
│       │       ├── ui/
│       │       │   ├── theme/           # 컬러, 타이포, 테마
│       │       │   ├── home/            # 내 서재 화면
│       │       │   ├── search/          # 책 검색 화면
│       │       │   ├── detail/          # 책 상세 화면
│       │       │   └── components/      # 공통 컴포넌트
│       │       └── navigation/          # 네비게이션
│       ├── androidMain/      # Android 특화
│       └── desktopMain/      # macOS/Desktop 특화
├── server/                   # (불필요 — 로컬 온리)
├── gradle/
├── build.gradle.kts
└── settings.gradle.kts
```

---

## 📊 데이터 모델

### Book Entity

```kotlin
@Entity(tableName = "books")
data class BookEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val title: String,
    val author: String,
    val publisher: String,
    val isbn: String,
    val thumbnailUrl: String,       // 책 표지 URL
    val description: String = "",
    val status: ReadingStatus = ReadingStatus.WANT_TO_READ,
    val rating: Int? = null,        // 0~5 (완독 후 선택적)
    val memo: String = "",          // 한줄 메모
    val addedAt: Long = System.currentTimeMillis(),
    val finishedAt: Long? = null,
)

enum class ReadingStatus {
    WANT_TO_READ,   // 읽고 싶은
    READING,        // 읽는 중
    FINISHED,       // 완독
    DROPPED,        // 중단
}
```

---

## 🎨 화면 설계

### 1. 홈 (내 서재) — 메인 화면

```
┌──────────────────────────────┐
│  📚 내 서재            [🔍]  │  ← 상단바 + 검색 아이콘
├──────────────────────────────┤
│ [전체] [읽는 중] [완독] [+]  │  ← 상태 필터 칩 + 추가
├──────────────────────────────┤
│ ┌─────┐ ┌─────┐ ┌─────┐     │
│ │     │ │     │ │     │     │  ← 책 표지 그리드 (3열)
│ │ 📖  │ │ 📖  │ │ 📖  │     │
│ │     │ │     │ │     │     │
│ ├─────┤ ├─────┤ ├─────┤     │
│ │제목 │ │제목 │ │제목 │     │
│ │저자 │ │저자 │ │저자 │     │
│ └─────┘ └─────┘ └─────┘     │
│                              │
│ ┌─────┐ ┌─────┐             │
│ │     │ │     │             │
│ │ 📖  │ │ 📖  │             │
│ ...                          │
└──────────────────────────────┘
```

- 표지 이미지가 주인공 → 큰 썸네일
- 상태별 필터 칩 (가로 스크롤)
- 책 탭 → 상세 화면
- 책 길게 누르기 → 빠른 상태 변경 메뉴

### 2. 책 검색 화면

```
┌──────────────────────────────┐
│  [←]  책 검색                │
├──────────────────────────────┤
│  🔍 [검색어 입력...        ] │  ← 자동 검색 (debounce 300ms)
├──────────────────────────────┤
│ ┌─────┬──────────────────┐   │
│ │     │ 책 제목           │   │
│ │ 📖  │ 저자 · 출판사     │   │  ← 리스트 형태
│ │     │ 2024              │   │
│ └─────┴──────────────────┘   │
│ ┌─────┬──────────────────┐   │
│ │     │ 책 제목           │   │
│ │ 📖  │ 저자 · 출판사     │   │
│ │     │ 2023              │   │
│ └─────┴──────────────────┘   │
│ ...                          │
└──────────────────────────────┘
```

- 타이핑하면 300ms debounce 후 자동 검색
- 결과 탭 → 확인 후 바로 서재에 추가 (상태 선택 바텀시트)

### 3. 책 상세 화면

```
┌──────────────────────────────┐
│  [←]                   [⋮]  │
├──────────────────────────────┤
│         ┌──────────┐        │
│         │          │        │
│         │   📖     │        │  ← 큰 표지 이미지
│         │  (표지)  │        │
│         │          │        │
│         └──────────┘        │
│     책 제목                  │
│     저자 · 출판사            │
├──────────────────────────────┤
│  상태: [  읽는 중  ▼ ]      │  ← 드롭다운 / 칩 선택
├──────────────────────────────┤
│  ⭐⭐⭐⭐☆  (완독 시)       │  ← 별점 (선택적)
├──────────────────────────────┤
│  📝 메모                     │
│  ┌──────────────────────┐   │
│  │ 한줄 메모 입력...     │   │
│  └──────────────────────┘   │
├──────────────────────────────┤
│  📋 책 소개                  │
│  Lorem ipsum dolor sit...   │
└──────────────────────────────┘
```

---

## 🎨 디자인 방향

### 컬러 시스템

```
Primary:     #6B4226  (따뜻한 브라운 — 책/나무 느낌)
Secondary:   #E8D5B7  (크림 — 종이 느낌)
Background:  #FAFAF8  (약간 따뜻한 화이트)
Surface:     #FFFFFF
OnPrimary:   #FFFFFF
OnSurface:   #1A1A1A
Accent:      #D4853A  (강조용 오렌지-브라운)

Dark Mode:
Background:  #1A1612  (다크 브라운)
Surface:     #2D2520
```

### 타이포그래피
- Pretendard (한글) — 깔끔한 산세리프
- 제목은 약간 bold, 본문은 regular

### 디자인 키워드
- 미니멀, 따뜻한, 책방 느낌
- 책 표지가 UI의 중심
- 여백 넉넉하게
- 부드러운 라운드 코너 (16dp)
- 은은한 그림자

---

## 🔧 구현 태스크

### Phase 1: 프로젝트 셋업

#### Task 1-1: KMP 프로젝트 생성
- JetBrains Compose Multiplatform 템플릿으로 프로젝트 생성
- Android + Desktop (macOS) 타겟 설정
- 패키지명: `com.kuneosu.bookshelf`

#### Task 1-2: 의존성 추가
- Room (KMP), Ktor (HTTP client), Coil 3, Koin, Navigation
- `gradle/libs.versions.toml`에 버전 카탈로그 설정

#### Task 1-3: 테마 & 디자인 시스템
- `ui/theme/` 에 Color, Typography, Theme 정의
- Light/Dark mode 지원

---

### Phase 2: 데이터 레이어

#### Task 2-1: Room DB 설정
- `BookEntity`, `ReadingStatus` 정의
- `BookDao` — CRUD + 상태별 필터 쿼리
- `BookDatabase` 생성 (KMP 플랫폼별 builder)

#### Task 2-2: 카카오 도서 검색 API 클라이언트
- Ktor HttpClient 설정
- `KakaoBookApi` — 검색 요청/응답 모델
- API 키 관리 (BuildConfig 또는 local.properties)

#### Task 2-3: Google Books API 클라이언트 (보조)
- `GoogleBooksApi` — 해외 서적 검색 폴백
- 카카오 결과가 없을 때 자동 폴백

#### Task 2-4: Repository 구현
- `BookRepository` — DB CRUD 래핑
- `SearchRepository` — 카카오 → Google 폴백 로직

---

### Phase 3: UI — 홈 (내 서재)

#### Task 3-1: 홈 화면 ViewModel
- `HomeViewModel` — 책 목록 로드, 상태 필터링
- `HomeUiState` sealed class

#### Task 3-2: 홈 화면 UI
- 상단 앱바 + 검색 아이콘
- 상태 필터 칩 바
- 책 표지 그리드 (LazyVerticalGrid, 3열)
- 빈 상태 일러스트

#### Task 3-3: 책 카드 컴포넌트
- 표지 이미지 (Coil), 제목, 저자
- 상태 뱃지 (컬러 도트)
- 길게 누르기 → 빠른 상태 변경

---

### Phase 4: UI — 책 검색 & 등록

#### Task 4-1: 검색 화면 ViewModel
- `SearchViewModel` — debounce 검색, 결과 관리

#### Task 4-2: 검색 화면 UI
- 검색바 (auto-focus)
- 검색 결과 리스트 (표지 + 제목 + 저자 + 출판사)
- 결과 탭 → 상태 선택 바텀시트 → 서재 추가

#### Task 4-3: 책 등록 바텀시트
- 상태 선택 (읽고 싶은 / 읽는 중 / 완독)
- 확인 → Room에 저장 → 홈으로 이동 + 토스트

---

### Phase 5: UI — 책 상세

#### Task 5-1: 상세 화면 ViewModel
- `DetailViewModel` — 책 정보 로드, 수정, 삭제

#### Task 5-2: 상세 화면 UI
- 큰 표지 이미지
- 책 정보 (제목, 저자, 출판사, ISBN)
- 상태 변경 드롭다운
- 별점 (완독 시)
- 한줄 메모 입력
- 삭제 버튼 (더보기 메뉴)

---

### Phase 6: 네비게이션 & 마무리

#### Task 6-1: 네비게이션 설정
- Compose Navigation 또는 Voyager
- 홈 → 검색, 홈 → 상세 화면 전환
- 애니메이션 (슬라이드)

#### Task 6-2: Desktop (macOS) 대응
- 윈도우 사이즈 설정
- 키보드 단축키 (Cmd+F: 검색)
- 데스크탑 레이아웃 조정 (더 넓은 그리드)

#### Task 6-3: 최종 QA & 폴리싱
- 빈 상태 처리
- 에러 상태 처리 (네트워크 오류 등)
- 로딩 상태 (Shimmer)
- 앱 아이콘

---

## 📅 예상 일정

| Phase | 내용 | 예상 시간 |
|-------|------|----------|
| Phase 1 | 프로젝트 셋업 | 1~2시간 |
| Phase 2 | 데이터 레이어 | 3~4시간 |
| Phase 3 | 홈 화면 | 2~3시간 |
| Phase 4 | 검색 & 등록 | 2~3시간 |
| Phase 5 | 상세 화면 | 2~3시간 |
| Phase 6 | 네비게이션 & 마무리 | 2~3시간 |
| **합계** | | **~12~18시간** |

---

## ⚠️ 잠재적 이슈 & 대응

1. **카카오 API 키 노출 방지** — `local.properties`에 저장, `.gitignore` 처리
2. **Room KMP 지원 제한** — Room KMP는 비교적 새로움. 문제 시 SQLDelight로 대체 가능
3. **macOS 이미지 로딩** — Coil 3 Desktop 지원 확인 필요. 문제 시 Kamel 라이브러리 대체
4. **한글 검색 인코딩** — Ktor에서 URL 인코딩 자동 처리 확인

---

## 🔑 사전 준비 (API 키)

1. **카카오 개발자 등록** — https://developers.kakao.com
   - 앱 등록 → REST API 키 발급
   - 도서 검색 API 활성화

2. **(선택) Google Cloud Console** — https://console.cloud.google.com
   - Books API 활성화 → API 키 발급
