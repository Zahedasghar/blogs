import { useMemo, useState } from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { motion } from "framer-motion";
import { TrendingUp, TrendingDown, RefreshCw } from "lucide-react";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  ReferenceLine,
} from "recharts";

// ---------------------------------------------
// Helper Functions
// ---------------------------------------------
function clamp(n, min, max) {
  return Math.max(min, Math.min(max, n));
}

// Generate straight-line demand curve points: Q = a - bP
function genDemandData(a, b, pMin = 0, pMax = 100, step = 5) {
  const arr = [];
  for (let P = pMin; P <= pMax; P += step) {
    arr.push({ P, Qd: Math.max(0, a - b * P) });
  }
  return arr;
}

// Generate straight-line supply curve points: Q = c + dP + shift
function genSupplyData(c, d, shift = 0, pMin = 0, pMax = 100, step = 5) {
  const arr = [];
  for (let P = pMin; P <= pMax; P += step) {
    arr.push({ P, Qs: Math.max(0, c + d * P + shift) });
  }
  return arr;
}

// Solve for equilibrium where a - bP = c + dP + shift
function solveEquilibrium(a, b, c, d, shift = 0) {
  const denom = b + d;
  const P = denom === 0 ? 0 : (a - c - shift) / denom;
  const Q = a - b * P;
  return { P: clamp(P, 0, 100), Q: clamp(Q, 0, 100) };
}

// ---------------------------------------------
// Main Component with Two Games
// ---------------------------------------------
export default function AdvancedEconGames() {
  return (
    <div className="min-h-screen w-full bg-gradient-to-b from-slate-50 via-white to-slate-100 p-6">
      <div className="mx-auto max-w-6xl">
        <h1 className="text-3xl font-bold tracking-tight text-slate-900 mb-2">
          Advanced Economics Game Lab
        </h1>
        <p className="text-slate-600 mb-6">
          Explore two interactive simulations: <span className="font-semibold">Elasticity Explorer</span> and <span className="font-semibold">Market Shocks Simulator</span>. Use the sliders and controls, watch the graphs update in real time, and aim for the learning goals shown in each panel.
        </p>

        <Tabs defaultValue="elasticity" className="w-full">
          <TabsList className="grid grid-cols-2 w-full md:w-auto">
            <TabsTrigger value="elasticity">Elasticity Explorer</TabsTrigger>
            <TabsTrigger value="shocks">Market Shocks Simulator</TabsTrigger>
          </TabsList>

          {/* ---------------- Elasticity Explorer ---------------- */}
          <TabsContent value="elasticity" className="mt-4">
            <ElasticityExplorer />
          </TabsContent>

          {/* ---------------- Market Shocks Simulator ------------- */}
          <TabsContent value="shocks" className="mt-4">
            <MarketShocksSimulator />
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
}

// ---------------------------------------------
// Game 1: Elasticity Explorer
// ---------------------------------------------
function ElasticityExplorer() {
  // Product presets with different elasticities (b controls slope)
  const products = {
    necessity: { label: "Rice (Necessity)", a: 120, b: 0.6 }, // inelastic (flatter Q change)
    normal: { label: "Shoes (Normal Good)", a: 120, b: 1.2 },
    luxury: { label: "Smartphone (Luxury)", a: 120, b: 2.2 }, // elastic (steeper Q change)
  };

  const [productKey, setProductKey] = useState("normal");
  const [price, setPrice] = useState(40);
  const [incomeBoost, setIncomeBoost] = useState(0); // shifts intercept a
  const [targetRevenue, setTargetRevenue] = useState(2500);
  const [showHints, setShowHints] = useState(true);

  const { a, b } = products[productKey];
  const effectiveA = a + incomeBoost; // income shifts demand outward/inward
  const Qd = Math.max(0, effectiveA - b * price);
  const revenue = price * Qd;
  const dQdP = -b; // slope of demand
  const PED = (dQdP * price) / (Qd || 1); // Point elasticity
  const elasticType = Math.abs(PED) > 1 ? "Elastic" : Math.abs(PED) < 1 ? "Inelastic" : "Unitary";

  const demandData = useMemo(() => genDemandData(effectiveA, b), [effectiveA, b]);

  // Classroom objective scoring: keep revenue within +/- 5% of target
  const withinTarget = Math.abs(revenue - targetRevenue) <= targetRevenue * 0.05;

  return (
    <Card className="shadow-xl rounded-2xl">
      <CardContent className="p-6 grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Controls */}
        <div className="space-y-5">
          <h2 className="text-xl font-semibold">Elasticity Explorer</h2>
          <p className="text-sm text-slate-600">
            Aim: Tune <span className="font-medium">Price</span> and <span className="font-medium">Income</span> to keep <span className="font-medium">Revenue</span> near your target. Watch how elasticity changes at different points on the curve.
          </p>

          <div className="grid gap-3">
            <label className="text-sm font-medium">Product Type</label>
            <Select value={productKey} onValueChange={setProductKey}>
              <SelectTrigger>
                <SelectValue placeholder="Select product" />
              </SelectTrigger>
              <SelectContent>
                {Object.entries(products).map(([k, v]) => (
                  <SelectItem key={k} value={k}>{v.label}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div>
            <div className="flex items-center justify-between text-sm font-medium">
              <span>Price (Rs)</span>
              <span className="tabular-nums">{price.toFixed(0)}</span>
            </div>
            <Slider min={0} max={100} step={1} value={[price]} onValueChange={(v) => setPrice(v[0])} />
          </div>

          <div>
            <div className="flex items-center justify-between text-sm font-medium">
              <span>Income Shift (Δa)</span>
              <span className="tabular-nums">{incomeBoost.toFixed(0)}</span>
            </div>
            <Slider min={-40} max={40} step={1} value={[incomeBoost]} onValueChange={(v) => setIncomeBoost(v[0])} />
          </div>

          <div>
            <div className="flex items-center justify-between text-sm font-medium">
              <span>Target Revenue</span>
              <span className="tabular-nums">Rs {targetRevenue.toFixed(0)}</span>
            </div>
            <Slider min={500} max={5000} step={50} value={[targetRevenue]} onValueChange={(v) => setTargetRevenue(v[0])} />
          </div>

          <div className="flex items-center gap-2">
            <Switch checked={showHints} onCheckedChange={setShowHints} id="hints" />
            <label htmlFor="hints" className="text-sm text-slate-700">Show revenue hints</label>
          </div>

          <div className="grid grid-cols-2 gap-3 text-sm">
            <Stat label="Quantity Demanded" value={`${Qd.toFixed(0)} units`} icon={<TrendingDown className="w-4 h-4" />} />
            <Stat label="Revenue" value={`Rs ${revenue.toFixed(0)}`} icon={<TrendingUp className="w-4 h-4" />} />
            <Stat label="PED" value={PED.toFixed(2)} />
            <Stat label="Elasticity Type" value={elasticType} />
          </div>

          {showHints && (
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className={`rounded-lg p-3 text-sm ${withinTarget ? "bg-emerald-50 text-emerald-700" : "bg-amber-50 text-amber-700"}`}>
              {withinTarget ? "Nice! Your pricing keeps revenue near the target." : PED < -1 ? "Demand is elastic: lowering price may raise revenue." : PED > -1 ? "Demand is inelastic: raising price may raise revenue." : "Unitary elasticity: revenue steady around here."}
            </motion.div>
          )}
        </div>

        {/* Chart */}
        <div className="h-[420px]">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={demandData} margin={{ top: 10, right: 20, left: 0, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="P" label={{ value: "Price (Rs)", position: "insideBottom", offset: -5 }} />
              <YAxis yAxisId="left" label={{ value: "Quantity", angle: -90, position: "insideLeft" }} />
              <Tooltip />
              <Legend />
              <Line yAxisId="left" type="monotone" dataKey="Qd" name="Demand" dot={false} />
              {/* Current point */}
              <ReferenceLine x={price} strokeDasharray="4 4" />
              <ReferenceLine y={Qd} strokeDasharray="4 4" />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </CardContent>
    </Card>
  );
}

function Stat({ label, value, icon }) {
  return (
    <div className="rounded-xl border bg-white/60 p-3 flex items-center gap-2">
      {icon}
      <div className="leading-tight">
        <div className="text-xs text-slate-500">{label}</div>
        <div className="text-sm font-semibold tabular-nums">{value}</div>
      </div>
    </div>
  );
}

// ---------------------------------------------
// Game 2: Market Shocks Simulator
// ---------------------------------------------
function MarketShocksSimulator() {
  // Base parameters
  const [a, setA] = useState(120); // demand intercept
  const [b, setB] = useState(1.2); // demand slope
  const [c, setC] = useState(10); // supply intercept
  const [d, setD] = useState(0.8); // supply slope
  const [shift, setShift] = useState(0); // supply shift from shocks/policy
  const [round, setRound] = useState(1);
  const [history, setHistory] = useState([]);

  const eq = solveEquilibrium(a, b, c, d, shift);

  const demandCurve = useMemo(() => genDemandData(a, b), [a, b]);
  const supplyCurve = useMemo(() => genSupplyData(c, d, shift), [c, d, shift]);

  // Random shock generator
  const shocks = [
    { key: "drought", label: "Drought (−Supply)", delta: -20 },
    { key: "tax", label: "Tax ↑ (−Supply)", delta: -15 },
    { key: "subsidy", label: "Subsidy (+Supply)", delta: 15 },
    { key: "tech", label: "New Tech (+Supply)", delta: 20 },
    { key: "reg", label: "Regulation (−Supply)", delta: -10 },
  ];

  function applyRandomShock() {
    const s = shocks[Math.floor(Math.random() * shocks.length)];
    setShift((prev) => prev + s.delta);
    setRound((r) => r + 1);
    setHistory((h) => [
      ...h,
      { round, event: s.label, newShift: shift + s.delta, eqP: eq.P.toFixed(1), eqQ: eq.Q.toFixed(1) },
    ]);
  }

  function resetMarket() {
    setA(120); setB(1.2); setC(10); setD(0.8); setShift(0); setRound(1); setHistory([]);
  }

  // Classroom objective: Bring market back near baseline equilibrium (shift≈0)
  const stability = 100 - Math.min(100, Math.abs(shift));

  return (
    <Card className="shadow-xl rounded-2xl">
      <CardContent className="p-6 grid grid-cols-1 xl:grid-cols-3 gap-6">
        {/* Controls */}
        <div className="space-y-5 xl:col-span-1">
          <h2 className="text-xl font-semibold">Market Shocks Simulator</h2>
          <p className="text-sm text-slate-600">
            Shocks shift the supply curve. Your goal is to stabilize the market by applying counter-policies and observing the new equilibrium.
          </p>

          {/* Base parameter sliders */}
          <ParamSlider label="Demand Intercept (a)" value={a} onChange={setA} min={60} max={160} />
          <ParamSlider label="Demand Slope (b)" value={b} onChange={setB} min={0.4} max={2.0} step={0.1} />
          <ParamSlider label="Supply Intercept (c)" value={c} onChange={setC} min={-10} max={40} />
          <ParamSlider label="Supply Slope (d)" value={d} onChange={setD} min={0.3} max={1.8} step={0.1} />

          <div>
            <div className="flex items-center justify-between text-sm font-medium">
              <span>Supply Shift (Σ shocks/policy)</span>
              <span className="tabular-nums">{shift.toFixed(0)}</span>
            </div>
            <Slider min={-60} max={60} step={1} value={[shift]} onValueChange={(v) => setShift(v[0])} />
          </div>

          <div className="flex gap-2 flex-wrap">
            <Button onClick={applyRandomShock} className="gap-2"><RefreshCw className="w-4 h-4"/> Next Round: Shock</Button>
            <Button variant="outline" onClick={() => setShift((s) => s + 10)}>Apply Subsidy (+)</Button>
            <Button variant="outline" onClick={() => setShift((s) => s - 10)}>Apply Tax (−)</Button>
            <Button variant="secondary" onClick={resetMarket}>Reset</Button>
          </div>

          <div className="grid grid-cols-2 gap-3 text-sm">
            <Stat label="Eq. Price" value={`Rs ${eq.P.toFixed(1)}`} />
            <Stat label="Eq. Quantity" value={`${eq.Q.toFixed(1)} units`} />
            <Stat label="Stability Score" value={`${stability.toFixed(0)}/100`} />
            <Stat label="Round" value={round} />
          </div>

          <div className="rounded-lg border p-3 bg-white/60 h-32 overflow-auto text-sm">
            <div className="font-medium mb-1">Event Log</div>
            {history.length === 0 && <div className="text-slate-500">No shocks yet. Click "Next Round: Shock".</div>}
            {history.map((h, i) => (
              <div key={i} className="flex items-center justify-between py-1 border-b last:border-none">
                <span className="truncate">R{h.round}: {h.event}</span>
                <span className="tabular-nums text-slate-600">shift {h.newShift}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Charts */}
        <div className="xl:col-span-2 grid grid-cols-1 gap-6">
          <Card className="rounded-xl">
            <CardContent className="p-4 h-[360px]">
              <div className="text-sm text-slate-600 mb-1">Static Curves (current parameters)</div>
              <ResponsiveContainer width="100%" height="100%">
                <LineChart margin={{ top: 10, right: 20, left: 0, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis type="number" dataKey="P" domain={[0, 100]} label={{ value: "Price (Rs)", position: "insideBottom", offset: -5 }} />
                  <YAxis type="number" domain={[0, 140]} label={{ value: "Quantity", angle: -90, position: "insideLeft" }} />
                  <Tooltip />
                  <Legend />
                  {/* Demand */}
                  <Line data={demandCurve.map((d) => ({ P: d.P, Q: d.Qd }))} type="monotone" dataKey="Q" name="Demand" dot={false} />
                  {/* Supply */}
                  <Line data={supplyCurve.map((s) => ({ P: s.P, Q: s.Qs }))} type="monotone" dataKey="Q" name="Supply" dot={false} />
                  {/* Equilibrium */}
                  <ReferenceLine x={eq.P} strokeDasharray="4 4" />
                  <ReferenceLine y={eq.Q} strokeDasharray="4 4" />
                </LineChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>

          <Card className="rounded-xl">
            <CardContent className="p-4 h-[360px]">
              <div className="text-sm text-slate-600 mb-1">Animated Market (quantity traded at each price)</div>
              <AnimatedMarketChart a={a} b={b} c={c} d={d} shift={shift} />
            </CardContent>
          </Card>
        </div>
      </CardContent>
    </Card>
  );
}

function ParamSlider({ label, value, onChange, min = 0, max = 100, step = 1 }) {
  return (
    <div>
      <div className="flex items-center justify-between text-sm font-medium">
        <span>{label}</span>
        <span className="tabular-nums">{typeof value === "number" ? value.toFixed(1) : value}</span>
      </div>
      <Slider min={min} max={max} step={step} value={[value]} onValueChange={(v) => onChange(v[0])} />
    </div>
  );
}

// Animated chart displaying traded quantity = min(Qd, Qs) across prices
function AnimatedMarketChart({ a, b, c, d, shift }) {
  const data = useMemo(() => {
    const rows = [];
    for (let P = 0; P <= 100; P += 5) {
      const Qd = Math.max(0, a - b * P);
      const Qs = Math.max(0, c + d * P + shift);
      const Qt = Math.min(Qd, Qs);
      rows.push({ P, Qd, Qs, Qt });
    }
    return rows;
  }, [a, b, c, d, shift]);

  return (
    <ResponsiveContainer width="100%" height="100%">
      <LineChart data={data} margin={{ top: 10, right: 20, left: 0, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="P" label={{ value: "Price (Rs)", position: "insideBottom", offset: -5 }} />
        <YAxis label={{ value: "Quantity", angle: -90, position: "insideLeft" }} />
        <Tooltip />
        <Legend />
        <Line type="monotone" dataKey="Qd" name="Demand" dot={false} />
        <Line type="monotone" dataKey="Qs" name="Supply" dot={false} />
        <Line type="monotone" dataKey="Qt" name="Quantity Traded" strokeDasharray="5 5" dot={false} />
      </LineChart>
    </ResponsiveContainer>
  );
}