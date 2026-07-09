# 피드필터 수집기 (Firefox 확장)

안드로이드 Firefox에서 **내 YouTube 홈 추천 영상을 피드필터 앱으로 수집**하는 확장입니다.
읽기 전용(화면에 로드된 링크만) · 온디맨드 · 쿠키를 서버로 보내지 않음.

## 준비
1. `config.js`를 열어 본인 Supabase 값으로 채우기 (앱과 동일):
   - `SUPABASE_URL`, `SUPABASE_ANON_KEY` (Supabase → Settings → API)

## 설치 (안드로이드 Firefox)
Firefox는 서명된 확장만 설치되므로 두 경로 중 하나:

**A. AMO 비공개(unlisted) 서명 후 설치 (권장, 안정적)**
1. 이 폴더를 zip으로 압축 (manifest.json이 zip 최상위에 오도록)
2. https://addons.mozilla.org/developers/ → Submit a New Add-on → **On your own (unlisted)** 업로드
3. 서명된 `.xpi` 다운로드 링크가 나오면, **안드로이드 Firefox에서 그 링크를 열어** 설치

**B. Firefox Nightly + 커스텀 컬렉션 (개발/테스트용)**
1. 안드로이드 **Firefox Nightly** 설치
2. 설정 → About Firefox Nightly 로고 5번 탭 → 디버그 메뉴 활성화
3. 설정 → Custom Add-on collection 에 AMO 컬렉션 지정 후, 그 컬렉션에서 설치

## 사용
1. Firefox에서 **youtube.com 홈**을 엶 (로그인된 상태)
2. 툴바의 확장 아이콘 탭 → 최초 1회 **앱 계정으로 로그인**
3. 스크롤 횟수 지정(기본 5) → **"이 화면의 홈 피드 수집"**
4. "완료! 저장 N개" 뜨면, 앱에서 **피드 새로고침**

## 동작
- 홈에 로드된 `/watch?v=` (일반) + `/shorts/` (쇼츠) 링크의 **영상 ID만** 수집
- 서버(`ingest-feed`)가 YouTube API로 제목·채널·썸네일·**카테고리**·길이를 보강
- 쇼츠는 저장하되 표시만 함 → 앱의 "쇼츠 포함" 토글로 켜고/끄기
- 중복은 자동 제거, 반복 수집 시 누적

## 주의
- 유튜브 앱이 아니라 **Firefox의 youtube.com**에서 수집합니다.
- 개인·비상업 용도. 자동 로그인/쿠키 전송 안 함(위험 최소화).
