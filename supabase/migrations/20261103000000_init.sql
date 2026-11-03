-- 국군장병 모집 통합 안내: 콘텐츠 테이블 (공개 읽기 전용)
-- 사이트는 anon 키로 SELECT만 하며, 수정은 Supabase 대시보드(Table Editor)에서 합니다.

create table if not exists public.branches (
  id                 text primary key,             -- army / navy / airforce / marine
  sort               int  not null,
  name               text not null,
  color              text not null,                -- CSS 값 (예: var(--army))
  short              text,
  env                text,
  feature            text,
  term_for_specialty text,                         -- 주특기 / 직별 / 특기
  official_url       text,
  phones             jsonb not null default '{}',  -- {"officer":[["라벨","전화"]], ...}
  phone_note         text,
  service_months     int                           -- 병 복무기간(개월)
);

create table if not exists public.ranks (
  branch_id text not null references public.branches(id) on delete cascade,
  id        text not null,                          -- officer / nco / enlisted / civilian
  sort      int  not null,
  name      text not null,
  welfare   jsonb not null default '[]',            -- [{"title","desc"}]
  primary key (branch_id, id)
);

create table if not exists public.tracks (
  id             bigint generated always as identity primary key,
  branch_id      text not null,
  rank_id        text not null,
  sort           int  not null,                     -- diagnosis_rules.track_sort 가 참조
  type           text not null check (type in ('civilian', 'active')),
  name           text not null,
  eligibility    text,
  training       text,
  service_period text,
  benefits       text,
  url            text,
  phone          text,
  foreign key (branch_id, rank_id) references public.ranks(branch_id, id) on delete cascade,
  unique (branch_id, rank_id, sort)
);

create table if not exists public.specialties (
  id        bigint generated always as identity primary key,
  branch_id text not null,
  rank_id   text not null,
  sort      int  not null,
  name      text not null,
  one_line  text,
  is_major  boolean not null default false,
  detail    jsonb,                                  -- {duty, requirements, servicePeriod, relatedMajors, relatedLicenses}
  fit       text[] not null default '{}',
  foreign key (branch_id, rank_id) references public.ranks(branch_id, id) on delete cascade,
  unique (branch_id, rank_id, sort)
);

create table if not exists public.diagnosis_rules (
  id         bigint generated always as identity primary key,
  sort       int  not null,
  branch_id  text not null,
  rank_id    text not null,
  track_sort int  not null,
  age_min    int  not null,
  age_max    int  not null,
  education  text[] not null,
  status     text[] not null,
  gender     text[] not null,
  foreign key (branch_id, rank_id, track_sort) references public.tracks(branch_id, rank_id, sort) on delete cascade
);

-- meta / commonWelfare / enlistment 같은 단일 문서형 콘텐츠
create table if not exists public.site_content (
  key   text primary key,
  value jsonb not null
);

-- 공개 읽기 전용: RLS 켜고 SELECT 정책만 허용
do $$
declare t text;
begin
  foreach t in array array['branches','ranks','tracks','specialties','diagnosis_rules','site_content'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "public read" on public.%I', t);
    execute format('create policy "public read" on public.%I for select to anon, authenticated using (true)', t);
    execute format('grant select on public.%I to anon, authenticated', t);
  end loop;
end $$;
