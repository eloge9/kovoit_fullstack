"use client";

import {
    BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
    ResponsiveContainer, LineChart, Line, Legend,
} from "recharts";

interface ChartData {
    date: string;
    net: number;
    commission: number;
    brut: number;
}

interface ChartRevenusProps {
    data: ChartData[];
    type?: "bar" | "line";
}

const fmtFCFA = (v: number) =>
    new Intl.NumberFormat("fr-FR", {
        style: "decimal",
        maximumFractionDigits: 0,
    }).format(v) + " F";

const fmtAxis = (v: number) =>
    v >= 1000 ? `${Math.round(v / 1000)}k` : String(v);

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

export default function ChartRevenus({ data, type = "bar" }: ChartRevenusProps) {
    if (type === "line") {
        return (
            <ResponsiveContainer width="100%" height={260}>
                <LineChart data={data} margin={{ top: 10, right: 16, left: 0, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" className="opacity-20" />
                    <XAxis dataKey="date" tick={{ fontSize: 11 }} tickLine={false} />
                    <YAxis tick={{ fontSize: 11 }} tickLine={false} tickFormatter={fmtAxis} />
                    <Tooltip content={<CustomTooltip />} />
                    <Legend />
                    <Line type="monotone" dataKey="net"        name="Net conducteur"  stroke="#22c55e" strokeWidth={2} dot={{ r: 3 }} />
                    <Line type="monotone" dataKey="commission" name="Commission Kovoit" stroke="#f59e0b" strokeWidth={2} dot={{ r: 3 }} strokeDasharray="5 4" />
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
                <Legend />
                <Bar dataKey="net"        name="Net conducteur"   fill="#22c55e" radius={[4, 4, 0, 0]} stackId="a" />
                <Bar dataKey="commission" name="Commission Kovoit" fill="#f59e0b" radius={[4, 4, 0, 0]} stackId="a" />
            </BarChart>
        </ResponsiveContainer>
    );
}
