"use client";

import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, LineChart, Line } from 'recharts';

interface ChartData {
  date: string;
  revenus: number;
  trajets: number;
}

interface ChartRevenusProps {
  data: ChartData[];
  type?: 'bar' | 'line';
}

export default function ChartRevenus({ data, type = 'bar' }: ChartRevenusProps) {
  const formatMontant = (value: number) => {
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'EUR',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(value);
  };

  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      return (
        <div className="bg-base-100 border border-base-200 rounded-lg p-3 shadow-lg">
          <p className="text-sm font-medium text-base-content">{label}</p>
          <p className="text-sm text-green-600">
            Revenus: {formatMontant(payload[0].value)}
          </p>
          <p className="text-sm text-blue-600">
            Trajets: {payload[0].payload.trajets}
          </p>
        </div>
      );
    }
    return null;
  };

  return (
    <div className="w-full h-64">
      <ResponsiveContainer width="100%" height="100%">
        {type === 'bar' ? (
          <BarChart data={data} margin={{ top: 10, right: 10, left: 10, bottom: 10 }}>
            <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
            <XAxis
              dataKey="date"
              tick={{ fontSize: 12 }}
              tickLine={false}
              axisLine={{ className: "opacity-30" }}
            />
            <YAxis
              tick={{ fontSize: 12 }}
              tickLine={false}
              axisLine={{ className: "opacity-30" }}
              tickFormatter={(value: number) => `${value}€`}
            />
            <Tooltip content={<CustomTooltip />} />
            <Bar
              dataKey="revenus"
              fill="rgb(34 197 94)"
              radius={[4, 4, 0, 0]}
              className="opacity-80"
            />
          </BarChart>
        ) : (
          <LineChart data={data} margin={{ top: 10, right: 10, left: 10, bottom: 10 }}>
            <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
            <XAxis
              dataKey="date"
              tick={{ fontSize: 12 }}
              tickLine={false}
              axisLine={{ className: "opacity-30" }}
            />
            <YAxis
              tick={{ fontSize: 12 }}
              tickLine={false}
              axisLine={{ className: "opacity-30" }}
              tickFormatter={(value: number) => `${value}€`}
            />
            <Tooltip content={<CustomTooltip />} />
            <Line
              type="monotone"
              dataKey="revenus"
              stroke="rgb(34 197 94)"
              strokeWidth={2}
              dot={{ fill: "rgb(34 197 94)", r: 4 }}
              activeDot={{ r: 6 }}
            />
          </LineChart>
        )}
      </ResponsiveContainer>
    </div>
  );
}
