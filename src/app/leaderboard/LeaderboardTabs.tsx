'use client'

import { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { IconTrophy, IconSwords } from '@/components/icons'

type SoloEntry = { name: string; userId: string; totalPoints: number; bestLevel: number; plays: number; avatar?: string }
type DuetEntry = { name: string; userId: string; wins: number; losses: number; draws: number; plays: number; avatar?: string }

const MEDALS = ['🥇', '🥈', '🥉']
const VIEW_OPTIONS = [
  { label: 'Top 10',  value: 10 },
  { label: 'Top 50',  value: 50 },
  { label: 'Top 100', value: 100 },
  { label: 'Svi',     value: 0 },
] as const
type ViewOption = typeof VIEW_OPTIONS[number]['value']

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
      <div className="flex p-1 rounded-full mb-6 max-w-md mx-auto" style={{ background: '#F2F2F2' }}>
        {([
          { id: 'solo', label: 'Solo', Icon: IconTrophy },
          { id: 'duet', label: 'Dueli', Icon: IconSwords },
        ] as const).map(({ id, label, Icon }) => (
          <button key={id} onClick={() => setTab(id)}
            className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-full text-[14px] font-semibold transition-all"
            style={tab === id
              ? { background: '#FCFCFC', color: '#343434', boxShadow: '0 2px 8px rgba(52,52,52,0.06)' }
              : { color: '#9C9C9C' }
            }>
            <Icon size={16} strokeWidth={2.2} />
            {label}
          </button>
        ))}
      </div>

      {tab === 'solo' && <SoloBoard data={soloData.length >= 3 ? soloData : DEMO_SOLO} isDemo={soloData.length < 3} user={user} />}
      {tab === 'duet' && <DuetBoard data={duetData.length >= 3 ? duetData : DEMO_DUET} isDemo={duetData.length < 3} user={user} />}
    </>
  )
}

function ViewTabs({ view, onChange, total }: { view: ViewOption; onChange: (v: ViewOption) => void; total: number }) {
  return (
    <div className="flex items-center gap-1.5 px-5 py-3.5 border-b overflow-x-auto" style={{ borderColor: '#F2F2F2' }}>
      {VIEW_OPTIONS.map(opt => {
        const count = opt.value === 0 ? total : Math.min(opt.value, total)
        const active = view === opt.value
        return (
          <button key={opt.value} onClick={() => onChange(opt.value)}
            className="flex-shrink-0 px-3 py-1.5 rounded-full text-[12px] font-semibold transition-all"
            style={active
              ? { background: '#343434', color: '#FCFCFC' }
              : { background: 'transparent', color: '#9C9C9C' }}>
            {opt.label}
            <span className="ml-1 opacity-60">({count})</span>
          </button>
        )
      })}
    </div>
  )
}

function Podium({ data, isDuet }: { data: (SoloEntry | DuetEntry)[]; isDuet: boolean }) {
  const heights = [40, 28, 22]
  return (
    <div className="px-6 pt-8 pb-6" style={{ background: 'linear-gradient(135deg, #BCD9FF 0%, #FFECBC 100%)' }}>
      <div className="flex items-end justify-center gap-3 sm:gap-5 max-w-md mx-auto">
        {[1, 0, 2].map(i => {
          const p = data[i]
          if (!p) return null
          return (
            <div key={i} className="text-center flex-1 min-w-0">
              <div className="text-2xl mb-1">{MEDALS[i]}</div>
              <div className="w-14 h-14 mx-auto mb-2 rounded-2xl overflow-hidden bg-white shadow-md">
                {p.avatar
                  ? <Image src={`/avatars/${p.avatar}`} alt={p.name} width={56} height={56} className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center font-bold text-[18px]" style={{ background: '#609DED', color: 'white' }}>{p.name[0]}</div>
                }
              </div>
              <div className="font-bold text-[13px] truncate tracking-tight" style={{ color: '#343434' }}>
                {p.name.split(' ')[0]}
              </div>
              <div className="text-[11px] font-medium" style={{ color: '#343434', opacity: 0.6 }}>
                {isDuet ? `${(p as DuetEntry).wins} W` : `${(p as SoloEntry).totalPoints} bod.`}
              </div>
              <div className="rounded-t-2xl mt-2 flex items-end justify-center pb-2"
                style={{ height: heights[i] * 2.5, background: '#FCFCFC', opacity: 0.85 }}>
                <span className="font-black text-[16px]" style={{ color: '#343434' }}>{i + 1}</span>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

function SoloBoard({ data, isDemo, user }: { data: SoloEntry[]; isDemo: boolean; user: boolean }) {
  const [view, setView] = useState<ViewOption>(10)

  if (data.length === 0) {
    return <EmptyState emoji="🎯" title="Solo rang lista je prazna" subtitle="Budi prvi koji će igrati!"
      href={user ? '/kvizovi' : '/auth/registracija'} label={user ? 'Idi na kvizove' : 'Registruj se'} />
  }

  const displayed = view === 0 ? data : data.slice(0, view)
  const isScroll = view === 0 && data.length > 10

  return (
    <div className="card-soft overflow-hidden">
      {data.length >= 3 && <Podium data={data} isDuet={false} />}
      {isDemo && (
        <div className="mx-5 mt-3 px-4 py-2.5 rounded-2xl text-[12px] text-center font-medium" style={{ background: '#FFECBC', color: '#9c7a13' }}>
          Primer kako izgleda rang lista
        </div>
      )}
      <ViewTabs view={view} onChange={setView} total={data.length} />
      <div className={isScroll ? 'max-h-[520px] overflow-y-auto' : ''}>
        {displayed.map((p, i) => {
          const row = (
            <>
              <span className="w-7 text-center flex-shrink-0">
                {i < 3 ? <span className="text-lg">{MEDALS[i]}</span> : <span className="text-[13px] font-bold" style={{ color: '#9C9C9C' }}>{i + 1}</span>}
              </span>
              <div className="w-10 h-10 rounded-2xl overflow-hidden flex-shrink-0 bg-[#F2F2F2]">
                {p.avatar
                  ? <Image src={`/avatars/${p.avatar}`} alt={p.name} width={40} height={40} className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center text-[14px] font-bold text-white" style={{ background: '#609DED' }}>{p.name[0]}</div>
                }
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#343434' }}>{p.name}</p>
                <p className="text-[12px]" style={{ color: '#9C9C9C' }}>Nivo {p.bestLevel} · {p.plays} {p.plays === 1 ? 'igra' : 'igara'}</p>
              </div>
              <div className="text-right flex-shrink-0">
                <div className="font-black text-[18px] tracking-tight" style={{ color: '#343434' }}>{p.totalPoints}</div>
                <div className="text-[11px]" style={{ color: '#9C9C9C' }}>bodova</div>
              </div>
            </>
          )
          return p.userId
            ? <Link key={i} href={`/profil/${p.userId}`} className="flex items-center gap-3 px-5 py-3.5 border-b last:border-0 hover:bg-[#F2F2F2] transition-colors" style={{ borderColor: '#F2F2F2' }}>{row}</Link>
            : <div key={i} className="flex items-center gap-3 px-5 py-3.5 border-b last:border-0" style={{ borderColor: '#F2F2F2' }}>{row}</div>
        })}
      </div>
    </div>
  )
}

function DuetBoard({ data, isDemo, user }: { data: DuetEntry[]; isDemo: boolean; user: boolean }) {
  const [view, setView] = useState<ViewOption>(10)

  if (data.length === 0) {
    return <EmptyState emoji="⚔️" title="Nema duel rezultata" subtitle="Izazovi prijatelja i budi prvi na listi!"
      href={user ? '/igraj-zajedno' : '/auth/registracija'} label={user ? 'Igraj zajedno' : 'Registruj se'} />
  }

  const displayed = view === 0 ? data : data.slice(0, view)
  const isScroll = view === 0 && data.length > 10

  return (
    <div className="card-soft overflow-hidden">
      {data.length >= 3 && <Podium data={data} isDuet={true} />}
      {isDemo && (
        <div className="mx-5 mt-3 px-4 py-2.5 rounded-2xl text-[12px] text-center font-medium" style={{ background: '#FFECBC', color: '#9c7a13' }}>
          Primer kako izgleda rang lista
        </div>
      )}
      <ViewTabs view={view} onChange={setView} total={data.length} />
      <div className={isScroll ? 'max-h-[520px] overflow-y-auto' : ''}>
        {displayed.map((p, i) => {
          const row = (
            <>
              <span className="w-7 text-center flex-shrink-0">
                {i < 3 ? <span className="text-lg">{MEDALS[i]}</span> : <span className="text-[13px] font-bold" style={{ color: '#9C9C9C' }}>{i + 1}</span>}
              </span>
              <div className="w-10 h-10 rounded-2xl overflow-hidden flex-shrink-0 bg-[#F2F2F2]">
                {p.avatar
                  ? <Image src={`/avatars/${p.avatar}`} alt={p.name} width={40} height={40} className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center text-[14px] font-bold text-white" style={{ background: '#609DED' }}>{p.name[0]}</div>
                }
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#343434' }}>{p.name}</p>
                <p className="text-[12px]" style={{ color: '#9C9C9C' }}>{p.plays} {p.plays === 1 ? 'duel' : 'duela'}</p>
              </div>
              <div className="flex gap-2.5 text-center flex-shrink-0">
                <div>
                  <div className="font-bold text-[15px]" style={{ color: '#4CAF50' }}>{p.wins}</div>
                  <div className="text-[10px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>W</div>
                </div>
                <div>
                  <div className="font-bold text-[15px]" style={{ color: '#9C9C9C' }}>{p.draws}</div>
                  <div className="text-[10px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>D</div>
                </div>
                <div>
                  <div className="font-bold text-[15px]" style={{ color: '#E55353' }}>{p.losses}</div>
                  <div className="text-[10px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>L</div>
                </div>
              </div>
            </>
          )
          return p.userId
            ? <Link key={i} href={`/profil/${p.userId}`} className="flex items-center gap-3 px-5 py-3.5 border-b last:border-0 hover:bg-[#F2F2F2] transition-colors" style={{ borderColor: '#F2F2F2' }}>{row}</Link>
            : <div key={i} className="flex items-center gap-3 px-5 py-3.5 border-b last:border-0" style={{ borderColor: '#F2F2F2' }}>{row}</div>
        })}
      </div>
    </div>
  )
}

function EmptyState({ emoji, title, subtitle, href, label }: {
  emoji: string; title: string; subtitle: string; href: string; label: string
}) {
  return (
    <div className="card-soft py-20 text-center px-6">
      <div className="text-5xl mb-4">{emoji}</div>
      <p className="font-bold text-[17px] mb-1" style={{ color: '#343434' }}>{title}</p>
      <p className="text-[14px] mb-6" style={{ color: '#9C9C9C' }}>{subtitle}</p>
      <Link href={href} className="btn btn-primary btn-md">{label}</Link>
    </div>
  )
}
