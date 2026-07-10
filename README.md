# 피드필터 (YouTube Feed Category Filter)

구독 채널의 최신 업로드를 가져와, **내가 고른 카테고리의 영상만** 골라 보는
Flutter 기반 PWA.

> ⚠️ YouTube는 공개 API로 개인 **홈 추천 피드**를 제공하지 않습니다. 이 앱은
> **구독 채널의 최신 업로드**를 서버가 수집해 카테고리별로 필터링합니다.

## 아키텍처

- **Flutter Web (PWA)** — GitHub Pages 배포, `--pwa-strategy none` + `version-info.json` 자가 업데이트
- **Riverpod** (`StateNotifier` / `FutureProvider`)
- **go_router** (hash URL, ShellRoute 하단 탭)
- **Supabase** — 이메일 인증 + Postgres(RLS) + Edge Functions(Deno)
- **오프라인 우선 동기화** — 로컬(shared_preferences) 즉시 표시 → 로그인 시 Supabase 미러링(pull-before-push)

### 데이터 모델

| 타입 | 저장 방식 | 테이블 |
|---|---|---|
| `FilterCategory` | blob (user_id별 1행 jsonb 배열) | `filter_categories` |
| `ChannelRule` | blob | `channel_rules` |
| `VideoState` | 행 단위 (user_id, video_id) | `video_states` |
| `FeedVideo` | 서버 수집 캐시 | `feed_videos` |
| Google 토큰 | 서버 전용(service_role) | `google_tokens` |

### 피드 수집 흐름

1. 마이 탭에서 Google OAuth 연결 → `connect-youtube` 함수가 refresh token 저장
2. `fetch-feed` 함수(매시 pg_cron)가 구독→업로드→카테고리 수집 후 `feed_videos`에 기록
3. 앱은 `feed_videos`를 pull, 활성 카테고리로 필터링해 표시

## 폴더 구조

```
lib/
  core/{config,supabase,storage,providers,router,theme,utils}
  features/{auth,feed,categories,channels,settings,update}/{models,services,providers,screens,widgets}
  shell/app_shell.dart
  app.dart · main.dart
supabase/{migrations,functions,cron,config.toml}
.github/workflows/{deploy-web.yml,cleanup-artifacts.yml}
```

## 첫 세팅 체크리스트 (사용자가 직접)

### A. Supabase
1. 프로젝트 생성 → `SUPABASE_URL`, `anon key` 확보
2. SQL Editor에서 `supabase/migrations/000*.sql` 순서대로 실행 (RLS 포함)
3. 스키마 캐시 이슈(404 PGRST205) 시: `NOTIFY pgrst, 'reload schema';`
4. Edge Functions 배포: `connect-youtube`, `fetch-feed`, `ingest-feed`, `tag-feed` 코드 붙여넣고 **Deploy updates**
5. 함수 Secrets 등록(공유 프로젝트 충돌 방지용 `YT_` 접두사): `YT_GOOGLE_CLIENT_ID`, `YT_GOOGLE_CLIENT_SECRET`, `YT_SCHEDULER_SECRET`, 그리고 세부 주제 자동 분류용 `ANTHROPIC_API_KEY` (`SUPABASE_URL`/`SERVICE_ROLE`는 자동)
6. pg_cron/pg_net 확장 활성화 후 `supabase/cron/fetch_feed_cron.sql`의 placeholder 치환해 실행

### B. Google Cloud
1. 프로젝트 생성 → **YouTube Data API v3** 사용 설정
2. OAuth 동의 화면 구성, 스코프 `youtube.readonly`
3. OAuth 클라이언트 ID(웹) 생성 → 승인된 리디렉션 URI에 Pages 도메인 등록
4. 클라이언트 ID/시크릿을 각각 GitHub/Supabase 시크릿에 등록

### C. GitHub
1. 저장소 Secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID`
2. Settings → Pages → Source를 **GitHub Actions**로
3. `claude/**` 또는 `main`에 push하면 자동 배포

## 내가(에이전트) 코드로 처리한 것

- Flutter 앱 전체 스캐폴드(core/auth/feed/categories/설정/자가업데이트)
- 카테고리 필터 기능(로컬+Supabase 동기화, RLS 테이블/마이그레이션)
- 데모 샘플 피드(가짜 데이터)로 필터 UI 동작 확인 가능
- Edge Functions(`connect-youtube`, `fetch-feed`, `ingest-feed`, `tag-feed`)와 cron 템플릿
- 세부 주제(세분화) 자동 분류: Claude Haiku가 영상별 태그를 붙이고, 카테고리에서 주제로 필터
- GitHub Pages 배포 워크플로우 + 아티팩트 정리

## 다음 단계

- [ ] 마이 탭 Google OAuth(GIS) 연결 버튼 → `connect-youtube` 호출
- [ ] 채널 규칙(음소거/즐겨찾기/카테고리 지정) 화면
- [ ] 시청/숨김/저장 상태(`video_states`) 반영
- [ ] 실제 피드로 카테고리 매핑 정확도 튜닝
