const json = (data, status = 200) =>
  Response.json(data, { status });

const randomKey = () => {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

  const part = () =>
    Array.from(
      { length: 4 },
      () => chars[Math.floor(Math.random() * chars.length)]
    ).join("");

  return `MBLY-${part()}-${part()}-${part()}`;
};

async function getScript(env) {
  if (!env.GITHUB_TOKEN) {
    throw new Error("GITHUB_TOKEN is not configured");
  }

  const response = await fetch(
    "https://api.github.com/repos/d3fy1337/main/contents/mblytrade.lua?ref=main",
    {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${env.GITHUB_TOKEN}`,
        "Accept": "application/vnd.github.raw+json",
        "User-Agent": "MBLYTRADE-Worker"
      }
    }
  );

  const body = await response.text();

  if (!response.ok) {
    throw new Error(`GitHub ${response.status}: ${body}`);
  }

  if (!body.trim()) {
    throw new Error("GitHub returned an empty script");
  }

  return body;
}

async function getLicense(env, key) {
  return await env.MBLY_DB
    .prepare(`
      SELECT *
      FROM licenses
      WHERE license_key = ?
      LIMIT 1
    `)
    .bind(String(key).trim())
    .first();
}

async function validateLicense(env, key, userId) {
  const cleanKey = String(key).trim();
  const cleanUserId = String(userId);

  const license = await getLicense(env, cleanKey);

  if (!license) {
    return {
      valid: false,
      error: "Invalid license"
    };
  }

  if (Number(license.active) !== 1) {
    return {
      valid: false,
      error: "License disabled"
    };
  }

  if (
    license.expires_at &&
    license.expires_at !== "lifetime"
  ) {
    const expires = new Date(license.expires_at);

    if (
      Number.isNaN(expires.getTime()) ||
      expires <= new Date()
    ) {
      return {
        valid: false,
        error: "License expired"
      };
    }
  }

  if (
    license.user_id &&
    String(license.user_id) !== cleanUserId
  ) {
    return {
      valid: false,
      error: "License is bound to another user"
    };
  }

  if (!license.user_id) {
    await env.MBLY_DB
      .prepare(`
        UPDATE licenses
        SET user_id = ?
        WHERE license_key = ?
      `)
      .bind(
        cleanUserId,
        cleanKey
      )
      .run();
  }

  return {
    valid: true,
    expires: license.expires_at || "lifetime"
  };
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (
      request.method === "GET" &&
      url.pathname === "/"
    ) {
      return new Response(
        "MBLYTRADE License API",
        {
          status: 200,
          headers: {
            "Content-Type":
              "text/plain; charset=utf-8"
          }
        }
      );
    }

    if (
      request.method === "POST" &&
      url.pathname === "/verify"
    ) {
      try {
        const body = await request.json();

        if (!body.key || !body.userId) {
          return json(
            {
              valid: false,
              error: "Missing key or userId"
            },
            400
          );
        }

        const result = await validateLicense(
          env,
          body.key,
          body.userId
        );

        if (!result.valid) {
          return json({
            valid: false,
            error: result.error
          });
        }

        return json({
          valid: true,
          expires: result.expires
        });
      } catch (error) {
        return json(
          {
            valid: false,
            error: String(error)
          },
          500
        );
      }
    }

    if (
      request.method === "POST" &&
      url.pathname === "/script"
    ) {
      try {
        const body = await request.json();

        if (!body.key || !body.userId) {
          return json(
            {
              error: "Missing key or userId"
            },
            400
          );
        }

        const result = await validateLicense(
          env,
          body.key,
          body.userId
        );

        if (!result.valid) {
          return json(
            {
              error: result.error
            },
            403
          );
        }

        const script = await getScript(env);

        return new Response(
          script,
          {
            status: 200,
            headers: {
              "Content-Type":
                "text/plain; charset=utf-8",
              "Cache-Control":
                "no-store"
            }
          }
        );
      } catch (error) {
        return json(
          {
            error: String(error)
          },
          500
        );
      }
    }

    const auth =
      request.headers.get("Authorization");

    if (
      !auth ||
      auth !== `Bearer ${env.ADMIN_SECRET}`
    ) {
      return json(
        {
          error: "Unauthorized"
        },
        401
      );
    }

    if (
      request.method === "POST" &&
      url.pathname === "/admin/create"
    ) {
      try {
        const body = await request.json();

        const key =
          body.key || randomKey();

        const userId =
          body.userId
            ? String(body.userId)
            : null;

        const expires =
          body.expires || "lifetime";

        await env.MBLY_DB
          .prepare(`
            INSERT INTO licenses
            (
              license_key,
              user_id,
              active,
              expires_at
            )
            VALUES (?, ?, 1, ?)
          `)
          .bind(
            key,
            userId,
            expires
          )
          .run();

        return json({
          success: true,
          key,
          userId,
          expires
        });
      } catch (error) {
        return json(
          {
            success: false,
            error: String(error)
          },
          400
        );
      }
    }

    if (
      request.method === "POST" &&
      url.pathname === "/admin/revoke"
    ) {
      try {
        const body = await request.json();

        if (!body.key) {
          return json(
            {
              success: false
            },
            400
          );
        }

        const result =
          await env.MBLY_DB
            .prepare(`
              UPDATE licenses
              SET active = 0
              WHERE license_key = ?
            `)
            .bind(
              String(body.key).trim()
            )
            .run();

        return json({
          success:
            result.meta.changes > 0
        });
      } catch {
        return json(
          {
            success: false
          },
          500
        );
      }
    }

    if (
      request.method === "POST" &&
      url.pathname === "/admin/reset"
    ) {
      try {
        const body = await request.json();

        if (!body.key) {
          return json(
            {
              success: false
            },
            400
          );
        }

        const result =
          await env.MBLY_DB
            .prepare(`
              UPDATE licenses
              SET user_id = NULL
              WHERE license_key = ?
            `)
            .bind(
              String(body.key).trim()
            )
            .run();

        return json({
          success:
            result.meta.changes > 0
        });
      } catch {
        return json(
          {
            success: false
          },
          500
        );
      }
    }

    if (
      request.method === "GET" &&
      url.pathname === "/admin/list"
    ) {
      try {
        const result =
          await env.MBLY_DB
            .prepare(`
              SELECT
                id,
                license_key,
                user_id,
                active,
                expires_at
              FROM licenses
              ORDER BY id DESC
            `)
            .all();

        return json({
          success: true,
          licenses: result.results
        });
      } catch {
        return json(
          {
            success: false
          },
          500
        );
      }
    }

    return new Response(
      "Not Found",
      {
        status: 404
      }
    );
  }
};
