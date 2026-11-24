create table if not exists public.quiz_results (
  id uuid primary key default gen_random_uuid(),
  name text not null check (name = btrim(name) and char_length(name) between 1 and 60),
  score integer not null check (score >= 0),
  total integer not null check (total between 1 and 100 and score <= total),
  created_at timestamptz not null default now()
);

create index if not exists quiz_results_score_created_at_idx
  on public.quiz_results (score desc, created_at desc);

alter table public.quiz_results enable row level security;
grant usage on schema public to anon;
revoke all on table public.quiz_results from public, anon, authenticated;
grant insert (name, score, total) on table public.quiz_results to anon;

drop policy if exists "public can submit quiz results" on public.quiz_results;
create policy "public can submit quiz results"
  on public.quiz_results
  for insert
  to anon
  with check (
    created_at >= now() - interval '5 minutes'
    and created_at <= now() + interval '1 minute'
  );

create or replace function public.quiz_leaderboard()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'resultados',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'id', recent.id,
            'name', recent.name,
            'score', recent.score,
            'total', recent.total
          )
          order by recent.score desc, recent.created_at desc
        )
        from (
          select id, name, score, total, created_at
          from public.quiz_results
          order by score desc, created_at desc
          limit 50
        ) as recent
      ),
      '[]'::jsonb
    ),
    'participantes',
    (select count(*)::integer from public.quiz_results),
    'acertos',
    (select coalesce(sum(score), 0)::integer from public.quiz_results),
    'perguntas',
    (select coalesce(sum(total), 0)::integer from public.quiz_results)
  );
$$;

revoke all on function public.quiz_leaderboard() from public, anon, authenticated;
grant execute on function public.quiz_leaderboard() to anon;
