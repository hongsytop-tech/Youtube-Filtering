# 피드필터 수집기 (브라우저 확장)

안드로이드 브라우저에서 **내 YouTube 홈 추천 영상을 피드필터 앱으로 수집**하는 확장입니다.
읽기 전용(화면에 로드된 링크만) · 온디맨드 · 쿠키를 서버로 보내지 않음.
Firefox와 Kiwi(크로미움) 등 **확장 지원 브라우저에서 동작**합니다.

## zip 받기 (GitHub이 자동 빌드)
`browser-extension/` 변경이 push되면 GitHub Actions가 zip을 빌드해
**Releases**의 `extension-latest`에 올립니다. 폰에서 바로 다운로드:

```
https://github.com/hongsytop-tech/Youtube-Filtering/releases/download/extension-latest/feedfilter-extension.zip
```

> config.js를 편집할 필요 없습니다 — Supabase URL/키는 **확장 팝업에서 입력**합니다.

## 설치

### A. Kiwi / Cromite (크로미움) — 폰만으로 가장 쉬움
1. 브라우저 설치 후 주소창에 `chrome://extensions`
2. **개발자 모드** 켜기 → **"압축 파일에서 로드"**(.zip) 로 위 zip 선택
3. (Kiwi는 zip을, 일부는 압축 해제 폴더를 요구 — 안내대로)

### B. Firefox
- **PC가 있으면**: `web-ext run -t firefox-android`(USB 디버깅)로 설치 — 가장 안정적
- **폰만**: 자체 서명(unlisted) xpi의 안드로이드 직접 설치는 제한적입니다.
  Firefox Nightly + AMO 컬렉션 방식이 필요하며, 이 경우 확장이 AMO에 공개됩니다.
  → 폰만/비공개라면 **A(크로미움)** 을 권장합니다.

## 사용
1. 브라우저에서 **youtube.com 홈**을 엶 (로그인된 상태)
2. 확장 아이콘 탭 → 최초 1회 **Supabase URL/anon key 입력**(앱과 동일 값) → 저장
3. **앱 계정으로 로그인**
4. 스크롤 횟수 지정(기본 5) → **"이 화면의 홈 피드 수집"**
5. "완료! 저장 N개" 뜨면, 앱에서 **피드 새로고침**

## 동작
- 홈에 로드된 `/watch?v=`(일반) + `/shorts/`(쇼츠) 링크의 **영상 ID만** 수집
- 서버(`ingest-feed`)가 YouTube API로 제목·채널·썸네일·**카테고리**·길이를 보강
- 쇼츠는 저장하되 표시만 함 → 앱의 "쇼츠 포함" 토글로 켜고/끄기
- 중복 자동 제거, 반복 수집 시 누적

## 주의
- 유튜브 앱이 아니라 **브라우저의 youtube.com**에서 수집합니다.
- 개인·비상업 용도. 자동 로그인/쿠키 전송 안 함(위험 최소화).
