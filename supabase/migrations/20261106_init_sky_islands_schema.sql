-- Sky Islands (Roblox) x Supabase Schema Migration

-- 1. 파일럿 프로필 (유저 진행도 & 최고 기록)
CREATE TABLE IF NOT EXISTS public.pilot_profiles (
    user_id BIGINT PRIMARY KEY,
    username TEXT NOT NULL,
    display_name TEXT,
    missions_completed INTEGER NOT NULL DEFAULT 0,
    stars INTEGER NOT NULL DEFAULT 0,
    best_lap_ms INTEGER,
    total_resets INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. 비행 코스 완주 기록 (타임어택 로그 & 텔레메트리)
CREATE TABLE IF NOT EXISTS public.flight_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL REFERENCES public.pilot_profiles(user_id),
    username TEXT NOT NULL,
    lap_time_ms INTEGER NOT NULL,
    top_speed INTEGER NOT NULL DEFAULT 0,
    max_altitude INTEGER NOT NULL DEFAULT 0,
    resets_used INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. 실시간 LiveOps 게임 설정 (재배포 없이 밸런스/공지 제어)
CREATE TABLE IF NOT EXISTS public.game_configs (
    key TEXT PRIMARY KEY,
    value_num DOUBLE PRECISION,
    value_text TEXT,
    description TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pilot_profiles_best_lap ON public.pilot_profiles (best_lap_ms ASC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_pilot_profiles_stars ON public.pilot_profiles (stars DESC);
CREATE INDEX IF NOT EXISTS idx_flight_records_lap_time ON public.flight_records (lap_time_ms ASC);

INSERT INTO public.game_configs (key, value_num, value_text, description)
VALUES
    ('heli_cruise_speed', 65, NULL, '헬기 기본 순항 속도 (25~100)'),
    ('star_reward', 100, NULL, '코스 1회 완주 시 지급하는 별 개수'),
    ('server_notice', NULL, '⚡ Supabase 실시간 랭킹 연동! 4개 섬 최단 기록에 도전하세요!', 'HUD에 표시할 실시간 서버 공지')
ON CONFLICT (key) DO NOTHING;

ALTER TABLE public.pilot_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flight_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_configs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public access pilot_profiles" ON public.pilot_profiles FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow public access flight_records" ON public.flight_records FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read game_configs" ON public.game_configs FOR SELECT USING (true);
