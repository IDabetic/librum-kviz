import DuelLobby from './DuelLobby'
import GameSeoContent from '@/components/GameSeoContent'

export const dynamic = 'force-dynamic'

// Server component wrapper. The interactive lobby is a client
// component that renders nothing until hydration (Suspense
// fallback={null}), so a crawler used to get a near-empty page —
// just 1 indexable word. The lobby keeps its own Header/Footer;
// GameSeoContent is server-rendered into the initial HTML so the
// page can actually rank for "kviz protiv prijatelja" / "trivia
// duel" / "multiplayer kviz".
export default function IgrajZajednoPage() {
  return (
    <>
      <DuelLobby />
      <GameSeoContent game="duel" />
    </>
  )
}
