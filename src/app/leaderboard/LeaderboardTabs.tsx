'use client'

import { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'

type SoloEntry = { name: string; userId: string; totalPoints: number; bestLevel: number; plays: number; avatar?: string }
type DuetEntry = { name: string; userId: string; wins: number; losses: number; draws: number; plays: number; avatar?: string }

const MEDALS = ['🥇', '🥈', '🥉']

const DEMO_DUET: DuetEntry[] = [
  { name: 'Marko Petrović',   userId: '', wins: 12, losses: 3,  draws: 1, plays: 16, avatar: 'avatar_03.jpg' },
  { name: 'Jovana Nikolić',   userId: '', wins: 10, losses: 4,  draws: 2, plays: 16, avatar: 'avatar_07.jpg' },
  { name: 'Stefan Đorđević',  userId: '', wins: 9,  losses: 5,  draws: 0, plays: 14, avatar: 'avatar_12.jpg' },
  { name: 'Milica Stanković', userId: '', wins: 7,  losses: 6,  draws: 1, plays: 14, avatar: 'avatar_18.jpg' },
  { name: 'Nikola Ilić',      userId: '', wins: 6,  losses: 7,  draws: 2, plays: 15, avatar: 'avatar_21.jpg' },
  { name: 'Teodora Vasić',    userId: '', wins: 5,  losses: 8,  draws: 0, plays: 13, avatar: 'avatar_05.jpg' },
  { name: 'Aleksa Marinović', userId: '', wins: 4,  losses: 9,  draws: 1, plays: 14, avatar: 'avatar_14.jpg' },
]

const DEMO_SOLO: SoloEntry[] = [
  { name: 'Marko Petrović',   userId: '', totalPoints: 480, bestLevel: 9,  plays: 14, avatar: 'avatar_03.jpg' },
  { name: 'Jovana Nikolić',   userId: '', totalPoints: 410, bestLevel: 8,  plays: 12, avatar: 'avatar_07.jpg' },
  { name: 'Stefan Đorđević',  userId: '', totalPoints: 360, bestLevel: 7,  plays: 11, avatar: 'avatar_12.jpg' },
  { name: 'Milica Stanković', userId: '', totalPoints: 290, bestLevel: 6,  plays: 9,  avatar: 'avatar_18.jpg' },
  { name: 'Nikola Ilić',      userId: '', totalPoints: 240, bestLevel: 5,  plays: 8,  avatar: 'avatar_21.jpg' },
  { name: 'Teodora Vasić',    userId: '', totalPoints: 190, bestLevel: 4,  plays: 7,  avatar: 'avatar_05.jpg' },
  { name: 'Aleksa Marinović', userId: '', totalPoints: 140, bestLevel: 3,  plays: 6,  avatar: 'avatar_14.jpg' },
]

export default function LeaderboardTabs({
  soloData, duetData, user,
}: {
  soloData: SoloEntry[]
  duetData: DuetEntry[]
  user: boolean
}) {
  const [tab, setTab] = useState<'solo' | 'duet'>('solo')

  return (
    <>
      <div className="flex bg-white rounded-2xl p-1 shadow-sm mb-6">
        {(['solo', 'duet'] as const).map(t => (
          <button key={t} onClick={() => setTab(t)}
            className="flex-1 py-2.5 rounded-xl text-sm font-semibold transition-all"
            style={tab === t ? { background: '#2C2D81', color: 'white' } : { color: '#6b7280' }}>
            {t === 'solo' ? '🎯 Solo' : '⚔️ Duet'}
          </button>
        ))}
      </div>

      {tab === 'solo' && <SoloBoard data={soloData.length >= 3 ? soloData : DEMO_SOLO} isDemo={soloData.length < 3} user={user} />}
      {tab === 'duet' && <DuetBoard data={duetData.length >= 3 ? duetData : DEMO_DUET} isDemo={duetData.length < 3} user={user} />}
    </>
  )
}

function SoloBoard({ data, isDemo, user }: { data: SoloEntry[]; isDemo: boolean; user: boolean }) {
  if (data.length === 0) {
    return (
      <EmptyState emoji="🎯" title="Solo rang lista je prazna" subtitle="Budite prvi koji će igrati!"
        href={user ? '/kvizovi' : '/auth/registracija'} label={user ? 'Idi na kvizove' : 'Registruj se'} />
    )
  }
  return (
    <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
      {data.length >= 3 && (
        <div className="p-6 border-b border-gray-50"
          style={{ background: 'linear-gradient(135deg, #2C2D81 0%, #3766B0 100%)' }}>
          <div className="flex items-end justify-center gap-4">
            {[1, 0, 2].map(i => {
              const p = data[i]; if (!p) return null
              const heights = [32, 24, 20]
              return (
                <div key={i} className="text-center flex-1 max-w-[120px]">
                  <div className="text-2xl mb-1">{MEDALS[i]}</div>
                  <div className="text-white font-bold text-sm truncate">{p.name.split(' ')[0]}</div>
                  <div className="text-white/70 text-xs mb-2">{p.totalPoints} bod.</div>
                  <div className="rounded-t-xl flex items-end justify-center pb-2"
                    style={{ height: heights[i] * 3, background: 'rgba(255,255,255,0.15)' }}>
                    <span className="text-white font-black text-xl">{i + 1}</span>
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      )}
      {isDemo && (
        <div className="mx-4 mt-3 px-3 py-2 rounded-xl text-xs text-center font-medium" style={{ background: '#FFF8E8', color: '#92681a' }}>
          Primer kako izgleda rang lista — stvarni podaci se pojavljuju posle prvih igara
        </div>
      )}
      <div className={`divide-y divide-gray-50 ${data.length > 5 ? 'max-h-[420px] overflow-y-auto' : ''}`}>
        {data.map((p, i) => {
          const row = (
            <>
              <span className="w-8 text-center text-lg">
                {i < 3 ? MEDALS[i] : <span className="text-sm font-bold text-gray-400">{i + 1}</span>}
              </span>
              <div className="w-9 h-9 rounded-xl overflow-hidden flex-shrink-0">
                {p.avatar
                  ? <Image src={`/avatars/${p.avatar}`} alt={p.name} width={36} height={36} className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center text-sm font-bold text-white" style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}>{p.name[0]}</div>
                }
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-sm text-gray-800">{p.name}</p>
                <p className="text-xs text-gray-400">Nivo {p.bestLevel} · {p.plays} {p.plays === 1 ? 'igra' : 'igara'}</p>
              </div>
              <div className="text-right">
                <div className="font-bold text-lg"
                  style={{ color: i === 0 ? '#FDC361' : i === 1 ? '#3766B0' : i === 2 ? '#c08a4a' : '#5DBF94' }}>
                  {p.totalPoints}
                </div>
                <div className="text-xs text-gray-400">bodova</div>
              </div>
            </>
          )
          return p.userId
            ? <Link key={i} href={`/profil/${p.userId}`} className="flex items-center gap-4 px-6 py-4 hover:bg-gray-50 transition-colors">{row}</Link>
            : <div key={i} className="flex items-center gap-4 px-6 py-4">{row}</div>
        })}
      </div>
    </div>
  )
}

function DuetBoard({ data, isDemo, user }: { data: DuetEntry[]; isDemo: boolean; user: boolean }) {
  if (data.length === 0) {
    return (
      <EmptyState emoji="⚔️" title="Nema duel rezultata" subtitle="Izazovi prijatelja i budi prvi na listi!"
        href={user ? '/igraj-zajedno' : '/auth/registracija'} label={user ? 'Igraj zajedno' : 'Registruj se'} />
    )
  }
  return (
    <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
      {data.length >= 3 && (
        <div className="p-6 border-b border-gray-50"
          style={{ background: 'linear-gradient(135deg, #3766B0 0%, #5DBF94 100%)' }}>
          <div className="flex items-end justify-center gap-4">
            {[1, 0, 2].map(i => {
              const p = data[i]; if (!p) return null
              const heights = [32, 24, 20]
              return (
                <div key={i} className="text-center flex-1 max-w-[120px]">
                  <div className="text-2xl mb-1">{MEDALS[i]}</div>
                  <div className="text-white font-bold text-sm truncate">{p.name.split(' ')[0]}</div>
                  <div className="text-white/70 text-xs mb-2">{p.wins}W</div>
                  <div className="rounded-t-xl flex items-end justify-center pb-2"
                    style={{ height: heights[i] * 3, background: 'rgba(255,255,255,0.15)' }}>
                    <span className="text-white font-black text-xl">{i + 1}</span>
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      )}
      {isDemo && (
        <div className="mx-4 mt-3 px-3 py-2 rounded-xl text-xs text-center font-medium" style={{ background: '#FFF8E8', color: '#92681a' }}>
          Primer kako izgleda rang lista — stvarni podaci se pojavljuju posle prvih duela
        </div>
      )}
      <div className={`divide-y divide-gray-50 ${data.length > 5 ? 'max-h-[420px] overflow-y-auto' : ''}`}>
        {data.map((p, i) => {
          const row = (
            <>
              <span className="w-8 text-center text-lg">
                {i < 3 ? MEDALS[i] : <span className="text-sm font-bold text-gray-400">{i + 1}</span>}
              </span>
              <div className="w-9 h-9 rounded-xl overflow-hidden flex-shrink-0">
                {p.avatar
                  ? <Image src={`/avatars/${p.avatar}`} alt={p.name} width={36} height={36} className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center text-sm font-bold text-white" style={{ background: 'linear-gradient(135deg, #3766B0, #5DBF94)' }}>{p.name[0]}</div>
                }
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-sm text-gray-800">{p.name}</p>
                <p className="text-xs text-gray-400">{p.plays} {p.plays === 1 ? 'duel' : 'duela'}</p>
              </div>
              <div className="flex gap-3 text-center">
                <div><div className="font-bold text-sm" style={{ color: '#5DBF94' }}>{p.wins}</div><div className="text-xs text-gray-400">W</div></div>
                <div><div className="font-bold text-sm text-gray-400">{p.draws}</div><div className="text-xs text-gray-400">D</div></div>
                <div><div className="font-bold text-sm" style={{ color: '#e05252' }}>{p.losses}</div><div className="text-xs text-gray-400">L</div></div>
              </div>
            </>
          )
          return p.userId
            ? <Link key={i} href={`/profil/${p.userId}`} className="flex items-center gap-4 px-6 py-4 hover:bg-gray-50 transition-colors">{row}</Link>
            : <div key={i} className="flex items-center gap-4 px-6 py-4">{row}</div>
        })}
      </div>
    </div>
  )
}

function EmptyState({ emoji, title, subtitle, href, label }: {
  emoji: string; title: string; subtitle: string; href: string; label: string
}) {
  return (
    <div className="text-center py-20 bg-white rounded-2xl shadow-sm">
      <div className="text-5xl mb-4">{emoji}</div>
      <p className="text-lg font-medium text-gray-600">{title}</p>
      <p className="text-sm text-gray-400 mt-1 mb-6">{subtitle}</p>
      <Link href={href} className="inline-flex px-6 py-3 rounded-xl font-bold text-white" style={{ background: '#2C2D81' }}>
        {label}
      </Link>
    </div>
  )
}
