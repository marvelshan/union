import { tokensQuery } from "$lib/queries/tokens.svelte"
import { runFork } from "$lib/runtime"
import type { FetchDecodeGraphqlError } from "$lib/utils/queries"
import type { Tokens, UniversalChainId } from "@unionlabs/sdk/schema"
import { Effect, type Fiber, Option } from "effect"
import type { TimeoutException } from "effect/Cause"
import { SvelteMap } from "svelte/reactivity"

class TokensStore {
  data = $state(new SvelteMap<UniversalChainId, Option.Option<typeof Tokens.Type>>())
  error = $state(
    new SvelteMap<UniversalChainId, Option.Option<FetchDecodeGraphqlError | TimeoutException>>(),
  )
  fibers = $state(new SvelteMap<UniversalChainId, Fiber.RuntimeFiber<number, never>>())

  setData(chainId: UniversalChainId, data: Option.Option<typeof Tokens.Type>) {
    this.data.set(chainId, data)
  }

  setError(
    chainId: UniversalChainId,
    error: Option.Option<FetchDecodeGraphqlError | TimeoutException>,
  ) {
    this.error.set(chainId, error)
  }

  getData(chainId: UniversalChainId): Option.Option<typeof Tokens.Type> {
    return this.data.get(chainId) ?? Option.none()
  }

  getError(chainId: UniversalChainId): Option.Option<FetchDecodeGraphqlError | TimeoutException> {
    return this.error.get(chainId) ?? Option.none()
  }

  fetchTokens(chainId: UniversalChainId) {
    // If there's already a query running for this chain, don't start another one
    if (this.fibers.has(chainId)) {
      return
    }

    // Start new query and store its fiber
    const fiber = runFork(tokensQuery(chainId))
    this.fibers.set(chainId, fiber)
  }
}

export const tokensStore = new TokensStore()
