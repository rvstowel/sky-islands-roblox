local HttpService = game:GetService("HttpService")

local SupabaseService = {}

-- Supabase Project Configuration (rvstowel's Project)
local SUPABASE_URL = "https://lcnnurnjgyafgcdfrcri.supabase.co"
local SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxjbm51cm5qZ3lhZmdjZGZyY3JpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM5Mzk4OTAsImV4cCI6MjEwOTUxNTg5MH0.kmB2AfvTLKuomy1rmMweITWUa_v8z0-JAOrpBwxCAFc"

local function request(method, endpoint, body, extraHeaders)
	local headers = {
		["apikey"] = SUPABASE_KEY,
		["Authorization"] = "Bearer " .. SUPABASE_KEY,
		["Content-Type"] = "application/json",
	}
	if extraHeaders then
		for k, v in extraHeaders do
			headers[k] = v
		end
	end

	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = SUPABASE_URL .. "/rest/v1/" .. endpoint,
			Method = method,
			Headers = headers,
			Body = body and HttpService:JSONEncode(body) or nil,
		})
	end)

	if not ok or not response then
		warn("[Supabase] HTTP Request failed:", response)
		return nil
	end

	if not response.Success then
		warn(string.format("[Supabase] HTTP %d (%s): %s", response.StatusCode, endpoint, tostring(response.Body)))
		return nil
	end

	if response.Body and #response.Body > 0 then
		local decodeOk, data = pcall(function()
			return HttpService:JSONDecode(response.Body)
		end)
		if decodeOk then
			return data
		end
	end
	return true
end

-- 1. 실시간 LiveOps 게임 설정 조회 (game_configs 테이블)
function SupabaseService.fetchLiveConfigs()
	local rows = request("GET", "game_configs?select=key,value_num,value_text")
	if type(rows) ~= "table" then
		return nil
	end
	local configs = {}
	for _, row in rows do
		if row.key then
			configs[row.key] = {
				num = row.value_num,
				text = row.value_text,
			}
		end
	end
	return configs
end

-- 2. 파일럿 프로필 불러오기 또는 신규 생성 (pilot_profiles 테이블)
function SupabaseService.loadOrCreateProfile(player)
	local userId = player.UserId
	local rows = request("GET", string.format("pilot_profiles?user_id=eq.%d&select=*", userId))
	if type(rows) == "table" and rows[1] then
		return rows[1]
	end

	local newProfile = {
		user_id = userId,
		username = player.Name,
		display_name = player.DisplayName,
		missions_completed = 0,
		stars = 0,
		best_lap_ms = nil,
		total_resets = 0,
	}
	local created = request("POST", "pilot_profiles", newProfile, {
		["Prefer"] = "resolution=merge-duplicates,return=representation",
	})
	if type(created) == "table" and created[1] then
		return created[1]
	end
	return newProfile
end

-- 3. 파일럿 프로필 저장/업데이트 (Upsert)
function SupabaseService.saveProfile(player, statsTable)
	local payload = {
		user_id = player.UserId,
		username = player.Name,
		display_name = player.DisplayName,
		missions_completed = statsTable.missions or 0,
		stars = statsTable.stars or 0,
		best_lap_ms = statsTable.bestLapMs,
		total_resets = statsTable.totalResets or 0,
		updated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	}
	return request("POST", "pilot_profiles?on_conflict=user_id", payload, {
		["Prefer"] = "resolution=merge-duplicates,return=representation",
	})
end

-- 4. 비행 완주 랩 타임 기록 추가 (flight_records 테이블)
function SupabaseService.recordFlightLap(player, lapTimeMs, topSpeed, maxAltitude, resetsUsed)
	local payload = {
		user_id = player.UserId,
		username = player.Name,
		lap_time_ms = lapTimeMs,
		top_speed = topSpeed or 0,
		max_altitude = maxAltitude or 0,
		resets_used = resetsUsed or 0,
	}
	return request("POST", "flight_records", payload, {
		["Prefer"] = "return=minimal",
	})
end

-- 5. 글로벌 Top 랭킹 조회 (최단 기록 우선, 그다음 별 개수 순)
function SupabaseService.fetchTopLeaderboard(limit)
	local count = limit or 5
	local rows = request(
		"GET",
		string.format(
			"pilot_profiles?select=user_id,username,display_name,best_lap_ms,missions_completed,stars&order=best_lap_ms.asc.nullslast,stars.desc&limit=%d",
			count
		)
	)
	if type(rows) == "table" then
		return rows
	end
	return {}
end

return SupabaseService
