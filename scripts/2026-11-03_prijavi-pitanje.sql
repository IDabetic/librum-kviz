-- Prijava netačnog pitanja iz aplikacije (PRIMENJENO 03.11). Isto pravilo kao veb /api/report-question:
-- dva različita igrača gase pitanje do pregleda urednika. Stare dvostruke prijave postoje, pa nema unique indeksa.
create index if not exists question_reports_pitanje on public.question_reports (question_id);
-- funkcija public.prijavi_pitanje(p_id uuid, p_razlog text) returns jsonb: vidi migraciju „prijavi_pitanje” u Supabase.
