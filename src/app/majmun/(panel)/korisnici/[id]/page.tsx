import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import Image from 'next/image'
import { notFound } from 'next/navigation'
import { IconBack } from '@/components/icons'
import RoleEditor from './RoleEditor'

export const dynamic = 'force-dynamic'

export default async function UserProfile({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()
  const { data: u } = await supabase.from('profiles')
    .select('id, first_name, last_name, nickname, avatar, email, city, role, created_at')
    .eq('id', id).single()
  if (!u) notFound()

  // Aggregate stats
  const [survivor, hangman, quick] = await Promise.all([
    supabase.from('survivor_sessions').select('score, questions_reached, best_combo, created_at')
      .eq('user_id', id).order('created_at', { ascending: false }).limit(20),
    supabase.from('hangman_sessions').select('won, score, created_at')
      .eq('user_id', id).order('created_at', { ascending: false }).limit(20),
    supabase.from('quick_sessions').select('score, correct_count, accuracy, created_at')
      .eq('user_id', id).order('created_at', { ascending: false }).limit(20),
  ])

  const sBest = (survivor.data || []).length ? Math.max(...(survivor.data || []).map(s => s.score)) : 0
  const sTotal = (survivor.data || []).length
  const hWins = (hangman.data || []).filter(h => h.won).length
  const hTotal = (hangman.data || []).length
  const qBest = (quick.data || []).length ? Math.max(...(quick.data || []).map(q => q.score)) : 0
  const qTotal = (quick.data || []).length

  const name = u.nickname || `${u.first_name || ''} ${u.last_name || ''}`.trim() || 'Igrač'

  return (
    <div className="max-w-3xl space-y-5">

      <Link href="/majmun/korisnici" className="inline-flex items-center gap-1.5 text-[13px] font-medium transition-opacity hover:opacity-70" style={{ color: '#609DED' }}>
        <IconBack size={16} strokeWidth={2.2} /> Svi korisnici
      </Link>

      <div className="card-soft p-6">
        <div className="flex items-center gap-4 mb-5">
          <div className="w-16 h-16 rounded-2xl overflow-hidden flex-shrink-0 bg-[#F2F2F2]">
            {u.avatar
              ? <Image src={`/avatars/${u.avatar}`} alt={name} width={64} height={64} className="w-full h-full object-cover" />
              : <div className="w-full h-full flex items-center justify-center font-bold text-[20px] text-white" style={{ background: '#609DED' }}>{name[0]}</div>}
          </div>
          <div className="min-w-0 flex-1">
            <h1 className="font-black tracking-tight truncate" style={{ color: '#343434', fontSize: 'clamp(20px, 4vw, 26px)' }}>{name}</h1>
            <p className="text-[13px] truncate" style={{ color: '#9C9C9C' }}>{u.email}</p>
            <p className="text-[11px] mt-0.5" style={{ color: '#9C9C9C' }}>
              ID: {u.id.substring(0, 8)}… · Pridružio se {new Date(u.created_at).toLocaleDateString('sr')}
            </p>
          </div>
        </div>

        <RoleEditor userId={u.id} currentRole={u.role} />
      </div>

      <div className="grid sm:grid-cols-2 gap-3">
        <StatCard label="PRO kviz" total={sTotal} primary={sBest} primaryLabel="Rekord" accent="#609DED" bg="#BCD9FF" />
        <StatCard label="Vešanje" total={hTotal} primary={hWins} primaryLabel="Pobeda" accent="#15803d" bg="#E8F8F0" />
        <StatCard label="Brzi kviz" total={qTotal} primary={qBest} primaryLabel="Rekord" accent="#b91c1c" bg="#FEE2E2" />
        <StatCard label="Ukupno" total={sTotal + hTotal + qTotal} primary={sTotal + hTotal + qTotal} primaryLabel="Igara" accent="#343434" bg="#F2F2F2" />
      </div>

      {/* Recent sessions */}
      {(survivor.data || []).length > 0 && (
        <div className="card-soft p-5">
          <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#9C9C9C' }}>Skorašnje PRO partije</p>
          <div className="space-y-1">
            {(survivor.data || []).slice(0, 5).map((s, i) => (
              <div key={i} className="flex items-center justify-between py-2 border-b last:border-0" style={{ borderColor: '#F2F2F2' }}>
                <div className="text-[13px]" style={{ color: '#343434' }}>{s.questions_reached} pitanja · niz {s.best_combo}</div>
                <div className="font-bold text-[14px]" style={{ color: '#609DED' }}>{s.score}</div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

function StatCard({ label, total, primary, primaryLabel, accent, bg }: {
  label: string; total: number; primary: number; primaryLabel: string; accent: string; bg: string
}) {
  return (
    <div className="card-soft p-5">
      <div className="flex items-center gap-2 mb-3">
        <div className="w-2 h-2 rounded-full" style={{ background: accent }} />
        <p className="font-bold text-[13px] tracking-tight" style={{ color: '#343434' }}>{label}</p>
      </div>
      <p className="font-black tracking-tight leading-none" style={{ color: accent, fontSize: 'clamp(22px, 4vw, 28px)' }}>{primary}</p>
      <p className="text-[11px] mt-1" style={{ color: '#9C9C9C' }}>{primaryLabel} · {total} sesija</p>
      <div className="mt-3 h-1 rounded-full" style={{ background: bg }} />
    </div>
  )
}
