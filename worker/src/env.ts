export interface Env {
  /** The Supabase project URL, e.g. https://abcd.supabase.co. A var, not a secret. */
  SUPABASE_URL: string;
  /** Service role key. Used only server-side to read a profile and its block list. */
  SUPABASE_SERVICE_ROLE_KEY: string;
  /**
   * Optional. Older projects sign access tokens with HS256 and this shared secret; newer
   * ones publish an asymmetric key at /auth/v1/.well-known/jwks.json and need nothing here.
   */
  SUPABASE_JWT_SECRET?: string;
  REGION: DurableObjectNamespace;
}
