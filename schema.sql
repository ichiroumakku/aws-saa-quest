-- aws-saa-quest : Supabase スキーマ定義
-- 新しい Supabase プロジェクト(aws-saa-quest / Tokyo)の SQL Editor で一度だけ実行する。
-- 旧 sc-study-app と同一構造(トリガー・関数なし。RLS ポリシーもダッシュボード相当)。

-- ========== questions ==========
create table if not exists public.questions (
  id              uuid primary key default gen_random_uuid(),
  exam_type       text,                       -- SAA-C03 のドメイン: D1/D2/D3/D4
  year            text,                       -- 生成バッチ識別子 (例: gen-2026-09)
  question_no     integer,
  field_tags      text[],                     -- fieldNames のキー (compute, storage, ...)
  difficulty      integer default 3,          -- 1=基礎 / 2=中間 / 3=本番同等
  body            text,
  choices         jsonb,                      -- {"ア":"...","イ":"...","ウ":"...","エ":"..."}
  official_answer text,                       -- "ア" | "イ" | "ウ" | "エ"
  explanation     text,
  created_at      timestamptz default now(),
  source          text                        -- sample | generated
);

-- ========== profiles ==========
create table if not exists public.profiles (
  user_id      uuid primary key references auth.users(id),
  display_name text,
  created_at   timestamptz default now()
);

-- ========== field_status ==========
create table if not exists public.field_status (
  user_id      uuid references auth.users(id),
  field_id     text,
  level        integer default 1,
  exp          integer default 0,
  mastery_rate numeric default 0,
  updated_at   timestamptz default now(),
  primary key (user_id, field_id)
);

-- ========== answer_logs ==========
create table if not exists public.answer_logs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid references auth.users(id),
  question_id   uuid references public.questions(id),
  user_answer   text,
  is_correct    boolean,
  partial_score numeric,
  exp_gained    integer default 0,
  created_at    timestamptz default now()
);

-- ========== chat_messages ==========
create table if not exists public.chat_messages (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id),
  question_id uuid references public.questions(id),
  role        text,        -- 'user' | 'assistant'
  content     text,
  created_at  timestamptz default now()
);

-- ========== RLS ==========
alter table public.questions     enable row level security;
alter table public.profiles      enable row level security;
alter table public.field_status  enable row level security;
alter table public.answer_logs   enable row level security;
alter table public.chat_messages enable row level security;

-- questions: 認証済みは全件閲覧。書き込みはサービスロール(SQL Editor)のみ。
create policy questions_select_all on public.questions
  for select using (auth.role() = 'authenticated');

-- profiles: 認証済みは全件閲覧(ランキング用)、本人のみ作成・更新
create policy profiles_select_all on public.profiles
  for select using (auth.role() = 'authenticated');
create policy profiles_insert_own on public.profiles
  for insert with check (auth.uid() = user_id);
create policy profiles_update_own on public.profiles
  for update using (auth.uid() = user_id);

-- field_status: 認証済みは全件閲覧(ランキング用)、本人のみ作成・更新
create policy field_status_select_all on public.field_status
  for select using (auth.role() = 'authenticated');
create policy field_status_insert_own on public.field_status
  for insert with check (auth.uid() = user_id);
create policy field_status_update_own on public.field_status
  for update using (auth.uid() = user_id);

-- answer_logs: 本人のみ
create policy answer_logs_select_own on public.answer_logs
  for select using (auth.uid() = user_id);
create policy answer_logs_insert_own on public.answer_logs
  for insert with check (auth.uid() = user_id);

-- chat_messages: 本人のみ
create policy chat_messages_select_own on public.chat_messages
  for select using (auth.uid() = user_id);
create policy chat_messages_insert_own on public.chat_messages
  for insert with check (auth.uid() = user_id);

-- ========== leaderboard (view) ==========
create or replace view public.leaderboard
  with (security_invoker = true) as
  select p.user_id,
         p.display_name,
         sum(fs.exp)              as total_exp,
         round(avg(fs.level), 1)  as avg_level,
         max(fs.level)            as top_field_level
    from public.profiles p
    join public.field_status fs on fs.user_id = p.user_id
   group by p.user_id, p.display_name
   order by sum(fs.exp) desc;
