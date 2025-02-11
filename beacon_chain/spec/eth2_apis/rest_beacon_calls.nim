# Copyright (c) 2018-2021 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.push raises: [Defect].}

import
  chronos, presto/client, chronicles,
  ".."/[helpers, forks], ".."/datatypes/[phase0, altair, merge],
  ".."/eth2_ssz_serialization,
  "."/[rest_types, eth2_rest_serialization]

export chronos, client, rest_types, eth2_rest_serialization

proc getGenesis*(): RestResponse[GetGenesisResponse] {.
     rest, endpoint: "/eth/v1/beacon/genesis",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getGenesis

proc getStateRoot*(state_id: StateIdent): RestResponse[GetStateRootResponse] {.
     rest, endpoint: "/eth/v1/beacon/states/{state_id}/root",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getStateRoot

proc getStateFork*(state_id: StateIdent): RestResponse[GetStateForkResponse] {.
     rest, endpoint: "/eth/v1/beacon/states/{state_id}/fork",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getStateFork

proc getStateFinalityCheckpoints*(state_id: StateIdent
          ): RestResponse[GetStateFinalityCheckpointsResponse] {.
     rest, endpoint: "/api/eth/v1/beacon/states/{state_id}/finality_checkpoints",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getStateFinalityCheckpoints

proc getStateValidators*(state_id: StateIdent,
                         id: seq[ValidatorIdent]
                        ): RestResponse[GetStateValidatorsResponse] {.
     rest, endpoint: "/eth/v1/beacon/states/{state_id}/validators",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getStateValidators

proc getStateValidator*(state_id: StateIdent,
                        validator_id: ValidatorIdent
                       ): RestResponse[GetStateValidatorResponse] {.
     rest,
     endpoint: "/eth/v1/beacon/states/{state_id}/validators/{validator_id}",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getStateValidator

proc getStateValidatorBalances*(state_id: StateIdent
                        ): RestResponse[GetStateValidatorBalancesResponse] {.
     rest, endpoint: "/eth/v1/beacon/states/{state_id}/validator_balances",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getStateValidators

proc getEpochCommittees*(state_id: StateIdent
                        ): RestResponse[GetEpochCommitteesResponse] {.
     rest, endpoint: "/eth/v1/beacon/states/{state_id}/committees",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getEpochCommittees

# TODO altair
# proc getEpochSyncCommittees*(state_id: StateIdent
#                         ): RestResponse[GetEpochSyncCommitteesResponse] {.
#      rest, endpoint: "/eth/v1/beacon/states/{state_id}/sync_committees",
#      meth: MethodGet.}
#   ## https://ethereum.github.io/beacon-APIs/#/Beacon/getEpochSyncCommittees

proc getBlockHeaders*(slot: Option[Slot], parent_root: Option[Eth2Digest]
                        ): RestResponse[GetBlockHeadersResponse] {.
     rest, endpoint: "/api/eth/v1/beacon/headers",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getBlockHeaders

proc getBlockHeader*(block_id: BlockIdent): RestResponse[GetBlockHeaderResponse] {.
     rest, endpoint: "/api/eth/v1/beacon/headers/{block_id}",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getBlockHeader

proc publishBlock*(body: phase0.SignedBeaconBlock): RestPlainResponse {.
     rest, endpoint: "/eth/v1/beacon/blocks",
     meth: MethodPost.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/publishBlock

proc publishBlock*(body: altair.SignedBeaconBlock): RestPlainResponse {.
     rest, endpoint: "/eth/v1/beacon/blocks",
     meth: MethodPost.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/publishBlock

proc getBlockPlain*(block_id: BlockIdent): RestPlainResponse {.
     rest, endpoint: "/api/eth/v1/beacon/blocks/{block_id}",
     accept: "application/octet-stream,application-json;q=0.9",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getBlock

proc getBlock*(client: RestClientRef, block_id: BlockIdent,
               restAccept = ""): Future[ForkedSignedBeaconBlock] {.async.} =
  let resp =
    if len(restAccept) > 0:
      await client.getBlockPlain(block_id, restAcceptType = restAccept)
    else:
      await client.getBlockPlain(block_id)
  let data =
    case resp.status
    of 200:
      case resp.contentType
      of "application/json":
        let blck =
          block:
            let res = decodeBytes(GetBlockResponse, resp.data,
                                  resp.contentType)
            if res.isErr():
              raise newException(RestError, $res.error())
            res.get()
        ForkedSignedBeaconBlock.init(blck.data)
      of "application/octet-stream":
        let blck =
          block:
            let res = decodeBytes(GetPhase0BlockSszResponse, resp.data,
                                  resp.contentType)
            if res.isErr():
              raise newException(RestError, $res.error())
            res.get()
        ForkedSignedBeaconBlock.init(blck)
      else:
        raise newException(RestError, "Unsupported content-type")
    of 400, 404, 500:
      let error =
        block:
          let res = decodeBytes(RestGenericError, resp.data, resp.contentType)
          if res.isErr():
            let msg = "Incorrect response error format (" & $resp.status &
                      ") [" & $res.error() & "]"
            raise newException(RestError, msg)
          res.get()
      let msg = "Error response (" & $resp.status & ") [" & error.message & "]"
      raise newException(RestError, msg)
    else:
      let msg = "Unknown response status error (" & $resp.status & ")"
      raise newException(RestError, msg)
  return data

proc getBlockV2Plain*(block_id: BlockIdent): RestPlainResponse {.
     rest, endpoint: "/api/eth/v2/beacon/blocks/{block_id}",
     accept: "application/octet-stream,application-json;q=0.9",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getBlockV2

proc getBlockV2*(client: RestClientRef, block_id: BlockIdent,
                 forks: array[2, Fork],
                 restAccept = ""): Future[ForkedSignedBeaconBlock] {.
     async.} =
  let resp =
    if len(restAccept) > 0:
      await client.getBlockV2Plain(block_id, restAcceptType = restAccept)
    else:
      await client.getBlockV2Plain(block_id)
  let data =
    case resp.status
    of 200:
      case resp.contentType
      of "application/json":
        let blck =
          block:
            let res = decodeBytes(GetBlockV2Response, resp.data,
                                  resp.contentType)
            if res.isErr():
              raise newException(RestError, $res.error())
            res.get()
        blck
      of "application/octet-stream":
        let header =
          block:
            let res = decodeBytes(GetBlockV2Header, resp.data, resp.contentType)
            if res.isErr():
              raise newException(RestError, $res.error())
            res.get()
        if header.slot.epoch() < forks[1].epoch:
          let blck =
            block:
              let res = decodeBytes(GetPhase0BlockSszResponse, resp.data,
                                    resp.contentType)
              if res.isErr():
                raise newException(RestError, $res.error())
              res.get()
          ForkedSignedBeaconBlock.init(blck)
        else:
          let blck =
            block:
              let res = decodeBytes(GetAltairBlockSszResponse, resp.data,
                                    resp.contentType)
              if res.isErr():
                raise newException(RestError, $res.error())
              res.get()
          ForkedSignedBeaconBlock.init(blck)
      else:
        raise newException(RestError, "Unsupported content-type")
    of 400, 404, 500:
      let error =
        block:
          let res = decodeBytes(RestGenericError, resp.data, resp.contentType)
          if res.isErr():
            let msg = "Incorrect response error format (" & $resp.status &
                      ") [" & $res.error() & "]"
            raise newException(RestError, msg)
          res.get()
      let msg = "Error response (" & $resp.status & ") [" & error.message & "]"
      raise newException(RestError, msg)
    else:
      let msg = "Unknown response status error (" & $resp.status & ")"
      raise newException(RestError, msg)
  return data

proc getBlockRoot*(block_id: BlockIdent): RestResponse[GetBlockRootResponse] {.
     rest, endpoint: "/eth/v1/beacon/blocks/{block_id}/root",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getBlockRoot

proc getBlockAttestations*(block_id: BlockIdent
                        ): RestResponse[GetBlockAttestationsResponse] {.
     rest, endpoint: "/eth/v1/beacon/blocks/{block_id}/attestations",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getBlockAttestations

proc getPoolAttestations*(
    slot: Option[Slot],
    committee_index: Option[CommitteeIndex]
              ): RestResponse[GetPoolAttestationsResponse] {.
     rest, endpoint: "/api/eth/v1/beacon/pool/attestations",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getPoolAttestations

proc submitPoolAttestations*(body: seq[Attestation]): RestPlainResponse {.
     rest, endpoint: "/eth/v1/beacon/pool/attestations",
     meth: MethodPost.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/submitPoolAttestations

proc getPoolAttesterSlashings*(): RestResponse[GetPoolAttesterSlashingsResponse] {.
     rest, endpoint: "/api/eth/v1/beacon/pool/attester_slashings",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getPoolAttesterSlashings

proc submitPoolAttesterSlashings*(body: AttesterSlashing): RestPlainResponse {.
     rest, endpoint: "/api/eth/v1/beacon/pool/attester_slashings",
     meth: MethodPost.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/submitPoolAttesterSlashings

proc getPoolProposerSlashings*(): RestResponse[GetPoolProposerSlashingsResponse] {.
     rest, endpoint: "/api/eth/v1/beacon/pool/proposer_slashings",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getPoolProposerSlashings

proc submitPoolProposerSlashings*(body: ProposerSlashing): RestPlainResponse {.
     rest, endpoint: "/api/eth/v1/beacon/pool/proposer_slashings",
     meth: MethodPost.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/submitPoolProposerSlashings

proc submitPoolSyncCommitteeSignatures*(body: seq[RestSyncCommitteeMessage]): RestPlainResponse {.
     rest, endpoint: "/eth/v1/beacon/pool/sync_committees",
     meth: MethodPost.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/submitPoolSyncCommitteeSignatures

proc getPoolVoluntaryExits*(): RestResponse[GetPoolVoluntaryExitsResponse] {.
     rest, endpoint: "/api/eth/v1/beacon/pool/voluntary_exits",
     meth: MethodGet.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/getPoolVoluntaryExits

proc submitPoolVoluntaryExit*(body: SignedVoluntaryExit): RestPlainResponse {.
     rest, endpoint: "/api/eth/v1/beacon/pool/voluntary_exits",
     meth: MethodPost.}
  ## https://ethereum.github.io/beacon-APIs/#/Beacon/submitPoolVoluntaryExit
