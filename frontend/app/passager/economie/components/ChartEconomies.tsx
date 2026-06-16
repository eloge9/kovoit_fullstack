"use client";

import {
    BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
    ResponsiveContainer, LineChart, Line,
} from "recharts";

interface ChartData {
    date:        string;
    economies:   number;
    reservations: number;
}

interface ChartEconomiesProps {
    data: ChartData[];
    type: "bar" | "line";
}

const fmtFCFA = (v: number) =>
    new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 0 }).format(v) + " F";

const fmtAxis = (v: number) => (v >= 1000 ? `${Math.round(v / 1000)}k` : String(v));

const CustomTooltip = ({ active, payload, label }: {
    active?: boolean;
    payload?: { value: number; name: string; color: string }[];
    label?: string;
}) => {
    if (!active || !payload?.length) return null;
    return (
        <div className="bg-base-100 border border-base-200 rounded-xl p-3 shadow-lg text-sm">
            <p className="font-semibold text-base-content mb-1">{label}</p>
            {payload.map((p, i) => (
                <p key={i} style={{ color: p.color }}>
                    {p.name} : {fmtFCFA(p.value)}
                </p>
            ))}
        </div>
    );
};

export default function ChartEconomies({ data, type }: ChartEconomiesProps) {
    if (type === "line") {
        return (
            <ResponsiveContainer width="100%" height={260}>
                <LineChart data={data} margin={{ top: 10, right: 16, left: 0, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" className="opacity-20" />
                    <XAxis dataKey="date" tick={{ fontSize: 11 }} tickLine={false} />
                    <YAxis tick={{ fontSize: 11 }} tickLine={false} tickFormatter={fmtAxis} />
                    <Tooltip content={<CustomTooltip />} />
                    <Line type="monotone" dataKey="economies" name="Économies (FCFA)"
                        stroke="#22c55e" strokeWidth={2} dot={{ r: 3 }} />
                </LineChart>
            </ResponsiveContainer>
        );
    }

    return (
        <ResponsiveContainer width="100%" height={260}>
            <BarChart data={data} margin={{ top: 10, right: 16, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" className="opacity-20" />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} tickLine={false} />
                <YAxis tick={{ fontSize: 11 }} tickLine={false} tickFormatter={fmtAxis} />
                <Tooltip content={<CustomTooltip />} />
                <Bar dataKey="economies" name="Économies (FCFA)"
                    fill="#22c55e" radius={[4, 4, 0, 0]} />
            </BarChart>
        </ResponsiveContainer>
    );
}
