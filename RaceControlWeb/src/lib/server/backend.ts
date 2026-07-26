import "server-only";

const BASE_URL = (process.env.RACECONTROL_API_BASE_URL || "http://localhost:8000").replace(/\/+$/, "");
const API_TOKEN = process.env.RACECONTROL_API_TOKEN || "";

export class BackendError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

/**
 * Server-only fetch against the RaceControl backend, with the shared
 * API_TOKEN injected. Never import this from a Client Component.
 */
export async function callBackend<T>(
  path: string,
  searchParams?: Record<string, string | number | undefined>,
  revalidateSeconds = 3600,
): Promise<T> {
  const url = new URL(BASE_URL + path);
  if (searchParams) {
    for (const [key, value] of Object.entries(searchParams)) {
      if (value !== undefined) url.searchParams.set(key, String(value));
    }
  }

  const headers: Record<string, string> = {};
  if (API_TOKEN) headers.Authorization = `Bearer ${API_TOKEN}`;

  const res = await fetch(url, {
    headers,
    next: { revalidate: revalidateSeconds },
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new BackendError(res.status, body || res.statusText);
  }
  return (await res.json()) as T;
}
