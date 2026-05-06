'use client'

import { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import type { SurvivorRow } from './page'

const MEDALS = ['🥇', '🥈', '🥉']
const VIEW_OPTIONS = [
  { label: 'Top 10',  value: 10 },
  { label: 'Top 50',  value: 50 },
  { label: 'Top 100', value: 100 },
  { label: 'Svi',     value: 0 },
] as const
type ViewOption = typeof VIEW_OPTIONS[number]['value']

const PERIOD_OPTIONS = [
  { id: 'today', label: 'Danas' },
  { id: 'week',  label: 'Nedelja' },
  { id: 'month', label: 'Mesec' },
  { id: 'all',   label: 'Sve vreme' },
] as const
type PeriodId = typeof PERIOD_OPTIONS[number]['id']

const DEMO: SurvivorRow[] = [
  { userId: '', name: 'Marko Petrović',   avatar: 'avatar_03.jpg', score: 1450, questionsReached: 142, correctAnswers: 121, wrongAnswers: 21, accuracy: 85, bestCombo: 32, totalTime: 1820, createdAt: '' },
  { userId: '', name: 'Jovana Nikolić',   avatar: 'avatar_07.jpg', score: 1120, questionsReached: 118, correctAnswers: 95,  wrongAnswers: 23, accuracy: 80, bestCombo: 24, totalTime: 1620, createdAt: '' },
  { userId: '', name: 'Stefan Đorđević',  avatar: 'avatar_12.jpg', score: 980,  questionsReached: 102, correctAnswers: 84,  wrongAnswers: 18, accuracy: 82, bestCombo: 21, totalTime: 1480, createdAt: '' },
  { userId: '', name: 'Milica Stanković', avatar: 'avatar_18.jpg', score: 760,  questionsReached: 88,  correctAnswers: 70,  wrongAnswers: 18, accuracy: 79, bestCombo: 17, totalTime: 1290, createdAt: '' },
  { userId: '', name: 'Nikola Ilić',      avatar: 'avatar_21.jpg', score: 580,  questionsReached: 71,  correctAnswers: 56,  wrongAnswers: 15, accuracy: 78, bestCombo: 12, totalTime: 1080, createdAt: '' },
  { userId: '', name: 'Teodora Vasić',    avatar: 'avatar_05.jpg', score: 420,  questionsReached: 58,  correctAnswers: 44,  wrongAnswers: 14, accuracy: 75, bestCombo: 10, totalTime: 920,  createdAt: '' },
  { userId: '', name: 'Aleksa Marinović', avatar: 'avatar_14.jpg', score: 290,  questionsReached: 46,  correctAnswers: 33,  wrongAnswers: 13, accuracy: 71, bestCombo: 8,  totalTime: 740,  createdAt: '' },
]

export default function LeaderboardTabs({ today, week, month, all, user }: {
  today: SurvivorRow[]; week: SurvivorRow[]; month: SurvivorRow[]; all: SurvivorRow[]; user: boolean
}) {
  const [period, setPeriod] = useState<PeriodId>('today')
  const dataMap: Record<PeriodId, SurvivorRow[]> = { today, week, month, all }
  const data = dataMap[period]

  return (
    <>
      {/* Period switcher */}
      <div className="flex p-1 rounded-full mb-6 max-w-md mx-auto overflow-x-auto" style={{ background: '#F2F2F2' }}>
        {PERIOD_OPTIONS.map(opt => (
          <button key={opt.id} onClick={() => setPeriod(opt.id)}
            className="flex-1 py-2.5 px-3 rounded-full text-[13px] font-semibold transition-all whitespace-nowrap"
            style={period === opt.id
              ? { background: '#FCFCFC', color: '#343434', boxShadow: '0 2px 8px rgba(52,52,52,0.06)' }
              : { color: '#9C9C9C' }}>
            {opt.label}
          </button>
        ))}
      </div>

      <Board data={data.length > 0 ? data : DEMO} isDemo={data.length === 0} user={user} />
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
            {opt.label}<span className="ml-1 opacity-60">({count})</span>
          </button>
        )
      })}
    </div>
  )
}

function Podium({ data }: { data: SurvivorRow[] }) {
  const heights = [40, 28, 22]
  return (
    <div className="px-6 pt-8 pb-6" style={{ background: 'linear-gradient(135deg, #BCD9FF 0%, #FFECBC 100%)' }}>
      <div className="flex items-end justify-center gap-3 sm:gap-5 max-w-md mx-auto">
        {[1, 0, 2].map(i => {
          const p = data[i]; if (!p) return null
          return (
            <div key={i} className="text-center flex-1 min-w-0">
              <div className="text-2xl mb-1">{MEDALS[i]}</div>
              <div className="w-14 h-14 mx-auto mb-2 rounded-2xl overflow-hidden bg-white shadow-md">
                {p.avatar
                  ? <Image src={`/avatars/${p.avatar}`} alt={p.name} width={56} height={56} className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center font-bold text-[18px]" style={{ background: '#609DED', color: 'white' }}>{p.name[0]}</div>}
              </div>
              <div className="font-bold text-[13px] truncate tracking-tight" style={{ color: '#343434' }}>{p.name.split(' ')[0]}</div>
              <div className="text-[11px] font-medium" style={{ color: '#343434', opacity: 0.6 }}>{p.score} bod.</div>
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

function Board({ data, isDemo, user }: { data: SurvivorRow[]; isDemo: boolean; user: boolean }) {
  const [view, setView] = useState<ViewOption>(10)

  if (data.length === 0) {
    return (
      <div className="card-soft py-20 text-center px-6">
        <div className="text-5xl mb-4">🎯</div>
        <p className="font-bold text-[17px] mb-1" style={{ color: '#343434' }}>Rang lista je prazna</p>
        <p className="text-[14px] mb-6" style={{ color: '#9C9C9C' }}>Budi prvi koji će igrati!</p>
        <Link href={user ? '/igraj' : '/auth/registracija'} className="btn btn-primary btn-md">
          {user ? 'Kreni' : 'Registruj se'}
        </Link>
      </div>
    )
  }

  const displayed = view === 0 ? data : data.slice(0, view)
  const isScroll = view === 0 && data.length > 10

  return (
    <div className="card-soft overflow-hidden">
      {data.length >= 3 && <Podium data={data} />}
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
                  : <div className="w-full h-full flex items-center justify-center text-[14px] font-bold text-white" style={{ background: '#609DED' }}>{p.name[0]}</div>}
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#343434' }}>{p.name}</p>
                <p className="text-[12px]" style={{ color: '#9C9C9C' }}>
                  {p.questionsReached} pit. · {Math.round(p.accuracy)}% · niz {p.bestCombo}
                </p>
              </div>
              <div className="text-right flex-shrink-0">
                <div className="font-black text-[18px] tracking-tight" style={{ color: '#343434' }}>{p.score}</div>
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
