import { createClient } from '@/lib/supabase/server'

export const dynamic = 'force-dynamic'

export default async function DuelAdminPage() {
  const supabase = await createClient()
  const { data: rooms } = await supabase
    .from('game_rooms')
    .select('id, room_code, host_id, guest_id, host_score, guest_score, status, total_questions, game_format, created_at')
    .order('created_at', { ascending: false })
    .limit(100)

  const userIds = [...new Set((rooms || []).flatMap(r => [r.host_id, r.guest_id]).filter(Boolean))] as string[]
  const profMap: Record<string, string> = {}
  if (userIds.length) {
    const { data: profs } = await supabase.from('profiles').select('id, first_name, nickname').in('id', userIds)
    ;(profs || []).forEach((p: { id: string; first_name: string; nickname: string }) => {
      profMap[p.id] = p.nickname || p.first_name || 'Igrač'
    })
  }

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>Trivia duel</h1>
        <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>Skorašnjih 100 duela</p>
      </div>

      <div className="card-soft overflow-hidden">
        <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
          {(rooms || []).map(r => {
            const hostName = profMap[r.host_id] || 'Domaćin'
            const guestName = r.guest_id ? (profMap[r.guest_id] || 'Gost') : '—'
            const winner =
              r.status === 'finished'
                ? (r.host_score === r.guest_score ? 'Nerešeno'
                  : (r.host_score ?? 0) > (r.guest_score ?? 0) ? hostName : guestName)
                : null
            const statusColor = r.status === 'finished' ? '#4CAF50' : r.status === 'playing' ? '#FFCB46' : '#9C9C9C'
            return (
              <div key={r.id} className="px-5 py-3.5">
                <div className="flex items-center gap-2 mb-1.5 flex-wrap">
                  <span className="chip" style={{ background: 'rgba(52,52,52,0.08)', color: '#343434' }}>
                    {r.room_code}
                  </span>
                  <span className="chip" style={{ background: 'rgba(52,52,52,0.06)', color: statusColor }}>
                    {r.status}
                  </span>
                  <span className="text-[11px]" style={{ color: '#9C9C9C' }}>{r.game_format} · {r.total_questions} pit.</span>
                  <span className="text-[11px] ml-auto" style={{ color: '#9C9C9C' }}>
                    {new Date(r.created_at).toLocaleString('sr', { dateStyle: 'short', timeStyle: 'short' })}
                  </span>
                </div>
                <div className="flex items-center justify-between">
                  <p className="text-[14px]" style={{ color: '#343434' }}>
                    <strong>{hostName}</strong> <span style={{ color: '#609DED' }}>{r.host_score ?? 0}</span>
                    <span className="mx-2" style={{ color: '#9C9C9C' }}>vs</span>
                    <strong>{guestName}</strong> <span style={{ color: '#FFCB46' }}>{r.guest_score ?? 0}</span>
                  </p>
                  {winner && (
                    <span className="text-[12px] font-bold" style={{ color: winner === 'Nerešeno' ? '#9c7a13' : '#15803d' }}>
                      {winner === 'Nerešeno' ? '🤝 Nerešeno' : `🏆 ${winner}`}
                    </span>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
