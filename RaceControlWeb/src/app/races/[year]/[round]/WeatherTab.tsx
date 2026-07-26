"use client";

import { useWeather } from "@/lib/api";
import { LoadingState, ErrorState, EmptyState } from "@/components/StateViews";

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-border bg-surface p-4 text-center">
      <p className="tabular text-2xl font-bold">{value}</p>
      <p className="mt-1 text-xs uppercase tracking-wide text-muted">{label}</p>
    </div>
  );
}

export function WeatherTab({ year, round }: { year: number; round: number }) {
  const { data, error, isLoading } = useWeather(year, round, "R");

  if (isLoading) return <LoadingState label="Loading weather…" />;
  if (error) return <ErrorState message="Weather data isn't available for this race." />;
  if (!data || !data.available) return <EmptyState message="No weather data available for this session." />;

  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
      <Stat label="Air Temp" value={data.airTemp != null ? `${data.airTemp}°C` : "—"} />
      <Stat label="Track Temp" value={data.trackTemp != null ? `${data.trackTemp}°C` : "—"} />
      <Stat label="Max Track Temp" value={data.trackTempMax != null ? `${data.trackTempMax}°C` : "—"} />
      <Stat label="Humidity" value={data.humidity != null ? `${data.humidity}%` : "—"} />
      <Stat label="Wind Speed" value={data.windSpeed != null ? `${data.windSpeed} m/s` : "—"} />
      <Stat label="Rainfall" value={data.rainfall ? "Yes" : "No"} />
    </div>
  );
}
