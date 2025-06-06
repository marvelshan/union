import { runSync } from "$lib/runtime"
import { ChannelValidationError } from "$lib/services/transfer-ucs03-evm/errors.ts"
import { Channel, type Channels } from "@unionlabs/sdk/schema"
import { Effect } from "effect"

export const getChannelInfoEffect = (
  source_chain_id: string,
  destination_chain_id: string,
  channels: typeof Channels.Type,
): Effect.Effect<typeof Channel.Type, ChannelValidationError> =>
  Effect.gen(function*() {
    const channel = channels.find(
      chan =>
        // @ts-ignore
        chan.source_chain_id === source_chain_id
        // @ts-ignore
        && chan.destination_chain_id === destination_chain_id,
    )

    if (
      !channel
      || channel.source_connection_id === null
      || channel.source_channel_id === null
      || !channel.source_port_id
      || channel.destination_connection_id === null
      || channel.destination_channel_id === null
      || !channel.destination_port_id
    ) {
      return yield* Effect.fail(
        new ChannelValidationError({
          // @ts-ignore
          source_chain_id,
          destination_chain_id,
          cause: "Missing required channel information",
        }),
      )
    }

    return new Channel({
      // @ts-ignore
      source_chain_id,
      source_connection_id: channel.source_connection_id,
      source_channel_id: channel.source_channel_id,
      source_port_id: channel.source_port_id,
      destination_chain_id,
      destination_connection_id: channel.destination_connection_id,
      destination_channel_id: channel.destination_channel_id,
      destination_port_id: channel.destination_port_id,
    })
  })

export const getChannelInfoSafe = (
  source_chain_id: string,
  destination_chain_id: string,
  channels: typeof Channels.Type,
): typeof Channel.Type | null => {
  const result = runSync(
    Effect.either(getChannelInfoEffect(source_chain_id, destination_chain_id, channels)),
  )

  return result._tag === "Right" ? result.right : null
}
