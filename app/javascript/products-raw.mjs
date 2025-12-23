import signBogus from "./encryption/xbogus.mjs";
import signGnarly from "./encryption/xgnarly.mjs";
import axios from "axios";

const config = {
  browser: {
    secUa: '"Google Chrome";v="142", "Not?A_Brand";v="99", "Chromium";v="142"',
    language: "en-US",
    name: "Mozilla",
    online: true,
    platform: "MacIntel",
    userAgent:
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36",
    version:
      "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36",
  },
};

function encode(value, { preserveTrailingEquals = false } = {}) {
  let s = String(value ?? "");
  let trailing = "";
  if (preserveTrailingEquals) {
    const m = s.match(/=+$/);
    if (m) {
      trailing = m[0];
      s = s.slice(0, -trailing.length);
    }
  }
  return (
    encodeURIComponent(s).replace(/%[0-9a-f]{2}/g, (m) => m.toUpperCase()) +
    trailing
  );
}

function buildQuery(entries, preserveEqualsFor = new Set()) {
  const parts = [];
  for (const [k, v] of entries) {
    if (v === undefined || v === null) continue;
    const key = encode(k);
    const val = encode(String(v), {
      preserveTrailingEquals: preserveEqualsFor.has(k),
    });
    parts.push(`${key}=${val}`);
  }
  return parts.join("&");
}

export async function signParamsStable({ url, entries, body = "" }) {
  const baseUrl = url;
  const preserveEqualsFor = new Set(["msToken"]);
  const queryString = buildQuery(entries, preserveEqualsFor);
  const unsignedUrl = `${baseUrl}?${queryString}`;
  const bodyString =
    body === "" ? "" : typeof body === "string" ? body : JSON.stringify(body);

  const xBogus = signBogus(
    queryString,
    bodyString,
    config.browser.userAgent,
    Math.floor(Date.now() / 1000)
  );

  const xGnarly = signGnarly(
    queryString,
    bodyString,
    config.browser.userAgent,
    0,
    "5.1.1"
  );

  const signedUrl = `${unsignedUrl}&X-Bogus=${xBogus}&X-Gnarly=${xGnarly}`;

  return { signedUrl, xBogus, xGnarly, unsignedUrl, bodyString };
}

export async function getProductsRaw({
  cookie,
  oecSellerId,
  baseUrl,
  fp,
  timezoneOffset,
  startDate,
  endDate,
  pageNo = 0,
  pageSize = 10,
}) {
  // Calculate timezone offset in seconds (e.g., -28800 for PST)
  const timezoneOffsetSeconds = timezoneOffset || -28800;

  // Format dates as YYYY-MM-DD
  const startDateStr = startDate;
  const endDateStr = endDate;

  // Calculate end date for time_descriptor (next day)
  const endDateObj = new Date(endDateStr);
  endDateObj.setDate(endDateObj.getDate() + 1);
  const endDateNextDay = endDateObj.toISOString().split('T')[0];

  const payload = {
    request: {
      time_descriptor: {
        start: startDateStr,
        end: endDateNextDay,
        timezone_offset: timezoneOffsetSeconds,
      },
      ccr_available_date: new Date().toISOString().split('T')[0],
      search: {
        voc_statuses: [],
        gmv_ranges: [],
      },
      filter: {},
      list_control: {
        rules: [
          {
            direction: 2, // 2 = descending
            field: "gmv",
          },
        ],
        pagination: {
          size: pageSize,
          page: pageNo,
        },
      },
    },
  };

  const url = `${baseUrl}/api/v2/insights/seller/ttp/product/list/v2`;
  const referer = `${baseUrl}/compass/product-analysis?shop_region=US&timeRange=${startDateStr}%7C${endDateStr}`;

  const entries = [
    ["locale", "en"],
    ["language", "en"],
    ["oec_seller_id", oecSellerId],
    ["aid", "4068"],
    ["app_name", "i18n_ecom_shop"],
    ["fp", fp],
    ["device_platform", "web"],
    ["cookie_enabled", true],
    ["screen_width", 1512],
    ["screen_height", 982],
    ["browser_language", config.browser.language],
    ["browser_platform", config.browser.platform],
    ["browser_name", config.browser.name],
    ["browser_version", config.browser.version],
    ["browser_online", config.browser.online],
    ["timezone_name", "America/New_York"],
    ["use_content_type_definition", 1],
  ];

  // Prefer msToken from cookie if present; fall back to a generated token.
  const msTokenFromCookie = extractMsTokenFromCookie(cookie);
  const msToken = msTokenFromCookie || generateMsToken();
  entries.push(["msToken", msToken]);

  const { signedUrl } = await signParamsStable({
    entries,
    body: payload,
    url,
  });

  try {
    const response = await axios.post(signedUrl, payload, {
      headers: {
        "accept": "*/*",
        "accept-language": "en-US,en;q=0.9",
        "cache-control": "no-cache",
        "content-type": "application/json",
        "origin": baseUrl,
        "pragma": "no-cache",
        "priority": "u=1, i",
        "referer": referer,
        "sec-ch-ua": config.browser.secUa,
        "sec-ch-ua-mobile": "?0",
        "sec-ch-ua-platform": '"macOS"',
        "sec-fetch-dest": "empty",
        "sec-fetch-mode": "cors",
        "sec-fetch-site": "same-origin",
        "user-agent": config.browser.userAgent,
        "cookie": cookie,
      },
      timeout: 30000, // 30 second timeout
    });

    return response.data;
  } catch (error) {
    // If axios got a response with an error status code, return the response data
    if (error.response) {
      return error.response.data || {
        status_code: error.response.status || -2,
        status_msg: `HTTP ${error.response.status}`,
        error: error.message,
      };
    }
    
    // Network error or other axios error
    return {
      status_code: -2,
      status_msg: "request_failed",
      error: error.message,
      error_type: error.code || "UNKNOWN",
    };
  }
}

// Try to pull msToken from the raw cookie header
function extractMsTokenFromCookie(cookie) {
  if (!cookie) return null;
  const match = cookie.match(/(?:^|;\s*)msToken=([^;]+)/);
  return match ? match[1] : null;
}

// Fallback msToken generator (best-effort). TikTok may still override / validate this.
function generateMsToken() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
  let result = "";
  for (let i = 0; i < 107; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

