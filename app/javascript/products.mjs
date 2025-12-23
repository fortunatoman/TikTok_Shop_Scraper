import { getProductsRaw } from "./products-raw.mjs";

// If running in interactive mode (TTY), exit with helpful message
if (process.stdin.isTTY) {
  console.error(JSON.stringify({
    status_code: -1,
    status_msg: "This script expects JSON input via stdin. Usage: echo '<json>' | node products.mjs",
    error: true,
  }));
  process.exit(1);
}

// Read stdin for input data
let inputData = "";
let timeoutId;

// Set a timeout to prevent hanging indefinitely
timeoutId = setTimeout(() => {
  console.error(JSON.stringify({
    status_code: -1,
    status_msg: "Timeout: No input received within 5 seconds",
    error: true,
  }));
  process.exit(1);
}, 5000);

process.stdin.setEncoding('utf8');

process.stdin.on("data", (chunk) => {
  clearTimeout(timeoutId);
  inputData += chunk;
});

process.stdin.on("end", async () => {
  clearTimeout(timeoutId);
  try {
    if (!inputData || inputData.trim() === "") {
      throw new Error("No input data provided");
    }

    const params = JSON.parse(inputData);

    // Validate required parameters
    if (!params.cookie) {
      throw new Error("cookie parameter is required");
    }
    if (!params.oecSellerId) {
      throw new Error("oecSellerId parameter is required");
    }
    if (!params.baseUrl) {
      throw new Error("baseUrl parameter is required");
    }
    if (!params.fp) {
      throw new Error("fp parameter is required");
    }

    // Call the function with the provided parameters
    const result = await getProductsRaw({
      cookie: params.cookie,
      oecSellerId: params.oecSellerId,
      baseUrl: params.baseUrl,
      fp: params.fp,
      timezoneOffset: params.timezoneOffset,
      startDate: params.startDate,
      endDate: params.endDate,
      pageNo: params.pageNo || 0,
      pageSize: params.pageSize || 10,
    });

    // Output the result as JSON to stdout
    console.log(JSON.stringify(result));
  } catch (error) {
    // Output error as JSON to stdout (not stderr) so Ruby can parse it
    const errorResponse = {
      status_code: -1,
      status_msg: error.message,
      error: true,
      error_type: error.name || "ERROR",
    };
    console.log(JSON.stringify(errorResponse));
    process.exit(1);
  }
});

