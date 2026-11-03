// index.html 에 내장된 DATA 를 읽어 supabase/seed.sql 을 만듭니다.
// 사용: node scripts/gen-seed.mjs
import { readFileSync, writeFileSync } from "node:fs";
import vm from "node:vm";

const root = new URL("..", import.meta.url);
const html = readFileSync(new URL("index.html", root), "utf8");
const start = html.indexOf("const M = (");
const end = html.indexOf("/* ───────── 유틸");
if (start < 0 || end < 0) throw new Error("index.html 에서 DATA 블록을 찾지 못했습니다.");
const DATA = vm.runInNewContext(html.slice(start, end) + "\nDATA;");

const lit = v => v === undefined || v === null ? "null"
  : typeof v === "number" ? String(v)
  : typeof v === "boolean" ? String(v)
  : "'" + String(v).replace(/'/g, "''") + "'";
const json = v => v === undefined ? "null" : lit(JSON.stringify(v)) + "::jsonb";
const arr = a => "array[" + (a || []).map(lit).join(",") + "]::text[]";
const insert = (table, cols, rows) => rows.length
  ? `insert into public.${table} (${cols.join(", ")}) values\n` + rows.map(r => "  (" + r.join(", ") + ")").join(",\n") + ";\n"
  : "";

const branches = [], ranks = [], tracks = [], specs = [], rules = [];
DATA.branches.forEach((b, bi) => {
  branches.push([lit(b.id), bi, lit(b.name), lit(b.color), lit(b.short), lit(b.env), lit(b.feature),
    lit(b.termForSpecialty), lit(b.officialUrl), json(b.phones || {}), lit(b.phoneNote), lit(DATA.servicePeriods[b.id])]);
  b.ranks.forEach((r, ri) => {
    ranks.push([lit(b.id), lit(r.id), ri, lit(r.name), json(r.welfare || [])]);
    r.tracks.forEach((t, ti) => tracks.push([lit(b.id), lit(r.id), ti, lit(t.type), lit(t.name), lit(t.eligibility),
      lit(t.training), lit(t.servicePeriod), lit(t.benefits), lit(t.url), lit(t.phone)]));
    r.specialties.forEach((s, si) => specs.push([lit(b.id), lit(r.id), si, lit(s.name), lit(s.oneLine), lit(s.isMajor),
      json(s.detail), arr(s.fit)]));
  });
});
DATA.diagnosisRules.forEach((r, i) => rules.push([i, lit(r.branch), lit(r.rank), r.track, r.ageMin, r.ageMax,
  arr(r.education), arr(r.status), arr(r.gender)]));

const sql = `-- 자동 생성: node scripts/gen-seed.mjs (index.html 의 DATA 기준 ${DATA.meta.baseDate})
-- 기존 콘텐츠를 지우고 다시 넣습니다.
begin;
truncate public.diagnosis_rules, public.specialties, public.tracks, public.ranks, public.branches, public.site_content restart identity cascade;

${insert("branches", ["id", "sort", "name", "color", "short", "env", "feature", "term_for_specialty", "official_url", "phones", "phone_note", "service_months"], branches)}
${insert("ranks", ["branch_id", "id", "sort", "name", "welfare"], ranks)}
${insert("tracks", ["branch_id", "rank_id", "sort", "type", "name", "eligibility", "training", "service_period", "benefits", "url", "phone"], tracks)}
${insert("specialties", ["branch_id", "rank_id", "sort", "name", "one_line", "is_major", "detail", "fit"], specs)}
${insert("diagnosis_rules", ["sort", "branch_id", "rank_id", "track_sort", "age_min", "age_max", "education", "status", "gender"], rules)}
${insert("site_content", ["key", "value"], [
  [lit("meta"), json(DATA.meta)],
  [lit("commonWelfare"), json(DATA.commonWelfare)],
  [lit("enlistment"), json(DATA.enlistment)]
])}
commit;
`;
writeFileSync(new URL("supabase/seed.sql", root), sql);
console.log(`seed.sql: branches ${branches.length}, ranks ${ranks.length}, tracks ${tracks.length}, specialties ${specs.length}, rules ${rules.length}`);
