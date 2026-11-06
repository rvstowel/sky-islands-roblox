# 🚁 Sky Islands (Roblox x Supabase)

하늘에 떠 있는 4개의 섬 코스를 헬리콥터로 비행하며 타임어택 기록을 경쟁하는 Roblox 게임입니다. **Supabase(PostgreSQL)**와 실시간 연동되어 파일럿 프로필, 최단 랩 타임 랭킹, 비행 텔레메트리 로그, LiveOps 설정을 관리합니다.

## 주요 기능
- **물리 기반 헬리콥터 비행**: `VectorForce` 및 `AlignOrientation`을 활용한 호버링·전후진·선회·상승/하강 비행 시스템
- **Supabase 영구 데이터 연동 (`pilot_profiles`)**: 완주 횟수(`완료`), 보유 `별`, 개인 최단 기록(`best_lap_ms`) 자동 로드 및 저장
- **타임어택 기록 & 텔레메트리 (`flight_records`)**: 매 완주 시 랩 타임(ms), 최고 속도, 최고 고도, 리셋 횟수 기록
- **실시간 글로벌 Top 5 리더보드**: 우측 상단 HUD에 전체 유저 최단 완주 기록 및 별 보유량 실시간 표시
- **LiveOps 원격 제어 (`game_configs`)**: 게임 재배포 없이 헬기 순항 속도(`heli_cruise_speed`), 별 보상량(`star_reward`), 실시간 서버 공지(`server_notice`) 변경 가능

## 프로젝트 구조
```text
├── default.project.json                                   # Rojo 프로젝트 설정
├── src/
│   ├── ServerScriptService/
│   │   ├── SkyFlightServer.server.luau                    # 헬기 스폰, 물리 비행, 코스 판정 및 DB 동기화
│   │   └── SupabaseService.luau                           # Supabase PostgREST API 통신 모듈
│   └── StarterPlayerScripts/
│       └── SkyFlightHUD.client.luau                       # 비행 계기판, 조작키 바인딩, 글로벌 랭킹 UI
└── supabase/
    └── migrations/
        └── 20261106_init_sky_islands_schema.sql           # Supabase PostgreSQL 테이블 & RLS 스키마
```

## 조작 방법
- `W` / `S` (또는 방향키 상/하): 전진 / 후진
- `A` / `D` (또는 방향키 좌/우): 좌회전 / 우회전
- `Q` / `E`: 상승 / 하강 (키에서 손을 떼면 자동 호버링)
