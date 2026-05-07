import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import Image from 'next/image'
import { IconSearch } from '@/components/icons'

export const dynamic = 'force-dynamic'

type SP = { q?: string; role?: string; page?: string }

export default async function KorisniciPage({ searchParams }: { searchParams: Promise<SP> }) {
  const sp = await searchParams
  const supabase = await createClient()
  const PER = 50
  const page = Math.max(0, parseInt(sp.page || '0', 10))

  let query = supabase.from('profiles')
    .select('id, first_name, last_name, nickname, avatar, email, city, role, created_at', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(page * PER, page * PER + PER - 1)
  if (sp.q) query = query.or(`first_name.ilike.%${sp.q}%,last_name.ilike.%${sp.q}%,nickname.ilike.%${sp.q}%,email.ilike.%${sp.q}%`)
  if (sp.role && sp.role !== 'all') query = query.eq('role', sp.role)

  const { data, count } = await query
  const totalPages = Math.ceil((count ?? 0) / PER)

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>Korisnici</h1>
        <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>{count ?? 0} ukupno</p>
      </div>

      <form className="card-soft p-4 flex items-center gap-2 flex-wrap" action="/majmun/korisnici">
        <div className="relative flex-1 min-w-[200px]">
          <div className="absolute left-4 top-1/2 -translate-y-1/2" style={{ color: '#9C9C9C' }}><IconSearch size={16} strokeWidth={2.2} /></div>
          <input name="q" defaultValue={sp.q || ''} className="input pl-11" placeholder="Pretraga po imenu ili email-u…" />
        </div>
        <select name="role" defaultValue={sp.role || 'all'} className="input flex-shrink-0" style={{ width: 'auto', minWidth: 130 }}>
          <option value="all">Sve uloge</option>
          <option value="user">Korisnik</option>
          <option value="urednik">Urednik</option>
          <option value="moderator">Moderator</option>
          <option value="super_admin">Super admin</option>
        </select>
        <button type="submit" className="btn btn-primary btn-md">Pretraži</button>
      </form>

      <div className="card-soft overflow-hidden">
        <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
          {(data || []).map(u => {
            const name = u.nickname || `${u.first_name || ''} ${u.last_name || ''}`.trim() || 'Igrač'
            const isAdmin = ['urednik', 'moderator', 'super_admin'].includes(u.role)
            return (
              <Link key={u.id} href={`/majmun/korisnici/${u.id}`}
                className="px-5 py-4 hover:bg-[#F2F2F2] transition-colors flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl overflow-hidden flex-shrink-0 bg-[#F2F2F2]">
                  {u.avatar
                    ? <Image src={`/avatars/${u.avatar}`} alt={name} width={40} height={40} className="w-full h-full object-cover" />
                    : <div className="w-full h-full flex items-center justify-center text-[13px] font-bold text-white" style={{ background: '#609DED' }}>{name[0]}</div>}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#343434' }}>{name}</p>
                    {isAdmin && (
                      <span className="chip" style={{ background: '#FFCB46', color: '#343434' }}>{u.role.replace('_', ' ')}</span>
                    )}
                  </div>
                  <p className="text-[12px]" style={{ color: '#9C9C9C' }}>
                    {u.email}{u.city ? ` · ${u.city}` : ''}
                  </p>
                </div>
                <div className="text-[11px] flex-shrink-0" style={{ color: '#9C9C9C' }}>
                  {new Date(u.created_at).toLocaleDateString('sr')}
                </div>
              </Link>
            )
          })}
        </div>
      </div>

      {totalPages > 1 && (
        <div className="flex items-center justify-between pt-2">
          <p className="text-[12px]" style={{ color: '#9C9C9C' }}>Strana {page + 1} od {totalPages}</p>
          <div className="flex gap-2">
            {page > 0 && <Link href={`/majmun/korisnici?page=${page - 1}`} className="btn btn-secondary btn-sm">← Prethodna</Link>}
            {page < totalPages - 1 && <Link href={`/majmun/korisnici?page=${page + 1}`} className="btn btn-primary btn-sm">Sledeća →</Link>}
          </div>
        </div>
      )}
    </div>
  )
}
