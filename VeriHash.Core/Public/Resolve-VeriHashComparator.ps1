function Resolve-VeriHashComparator {
    <#
    .SYNOPSIS
        Decides what a computed hash should be compared against, if anything.
    .DESCRIPTION
        THE single source of truth for comparator selection. Both
        Format-VeriHashReport (the banner) and Invoke-VeriHashHotPath (the
        sidecar-write decision) call this. They previously each restated the
        rule by hand and disagreed: the clipboard branch was guarded in one
        copy and unguarded in the other, so an MD5 on the clipboard during a
        SHA256 run compared 32 characters against 64 and reported a false
        MISMATCH on an intact file.

        Public, not private, because VeriHash.HotPath calls it across a module
        boundary -- the same reason Format-VeriHashBatchTally is public. Both
        modules dot-source their own Private/ into their own scope, which
        PowerShell does not share, so a private helper here would resolve
        inside Core and throw CommandNotFoundException inside HotPath.

        A pasted hash is a QUESTION ('is this file the one this hash
        describes?'), not a comparator. When the question cannot be answered
        with the digest in hand, this returns 'unusable' rather than quietly
        falling back to the sidecar: answering a different question in a way
        the user will read as an answer to theirs is a worse failure than
        declining, because it fails green. No information is lost -- the
        checklist reports the sidecar on its own row regardless. What the
        banner declines to do is promote that fact into a verdict on a
        question it does not address.
    .PARAMETER CompareTo
        Clipboard hash record from Read-ClipboardHash, or $null. Three shapes:
        supported (Algorithm + Hash set), unsupported (Algorithm and Hash
        $null, Detail explains why), or absent ($null -- nothing on the
        clipboard was hash-shaped).
    .PARAMETER SidecarInfo
        Sidecar record from Test-VeriHashSidecar, or $null.
    .PARAMETER ComputedAlgorithm
        The algorithm the file was ACTUALLY hashed with this run.
    .OUTPUTS
        [pscustomobject]@{ Source; ExpectedHash; Algorithm; Reason }

        Source is one of:
          clipboard  -- compare against ExpectedHash (the user's question)
          sidecar    -- compare against ExpectedHash (the fallback)
          unusable   -- the user asked and we cannot answer; Reason says why
          none       -- the user never asked
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [pscustomobject]$CompareTo,
        [pscustomobject]$SidecarInfo,

        [Parameter(Mandatory)]
        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA512')]
        [string]$ComputedAlgorithm
    )

    function New-Comparator {
        param($Source, $ExpectedHash, $Algorithm, $Reason)
        return [pscustomobject]@{
            Source       = $Source
            ExpectedHash = $ExpectedHash
            Algorithm    = $Algorithm
            Reason       = $Reason
        }
    }

    # --- 1/2. the clipboard, when there is one ------------------------------
    # A clipboard record present at all means the user asked a question. From
    # here the only outcomes are 'clipboard' (answered) or 'unusable' (asked,
    # cannot answer). The sidecar is never substituted for a question the user
    # actually posed.
    if ($CompareTo) {
        if ($CompareTo.Algorithm -and $CompareTo.Hash) {
            if ($CompareTo.Algorithm -eq $ComputedAlgorithm) {
                $expected = ([string]$CompareTo.Hash).ToLowerInvariant()

                # Equal algorithm names must imply equal hex length. If they
                # ever disagree that is a bug in hash parsing, not a mismatched
                # file, and reporting it as a mismatch would blame the user's
                # download for our defect.
                if ($expected.Length -ne (Get-VeriHashHexLength -Algorithm $ComputedAlgorithm)) {
                    throw "clipboard hash claims $ComputedAlgorithm but is $($expected.Length) hex characters"
                }

                return New-Comparator -Source 'clipboard' -ExpectedHash $expected `
                                      -Algorithm $CompareTo.Algorithm -Reason $null
            }

            # Wrong algorithm: recognised fine, just not answerable by the
            # digest this run computed.
            return New-Comparator -Source 'unusable' -ExpectedHash $null -Algorithm $CompareTo.Algorithm `
                -Reason "clipboard holds $($CompareTo.Algorithm); this run computed $ComputedAlgorithm"
        }

        # Recognised as hash-shaped but of a length VeriHash does not
        # implement. Read-ClipboardHash carries the explanation in Detail.
        $detail = if ($CompareTo.PSObject.Properties['Detail'] -and $CompareTo.Detail) {
            [string]$CompareTo.Detail
        } else {
            'clipboard hash could not be used'
        }
        return New-Comparator -Source 'unusable' -ExpectedHash $null -Algorithm $null -Reason $detail
    }

    # --- 3. the sidecar, as a fallback when nothing was asked ---------------
    # Algorithm guard: Get-PreferredSidecar picks .sha512 > .sha256 > .md5 and
    # Test-VeriHashSidecar hashes with WHICHEVER it found, while this run
    # hashed with its own algorithm. Comparing across the two would report a
    # false MISMATCH on a good file -- the same defect this function exists to
    # prevent on the clipboard side.
    if ($SidecarInfo -and $SidecarInfo.ExpectedHash -and $SidecarInfo.Algorithm -eq $ComputedAlgorithm) {
        return New-Comparator -Source 'sidecar' `
                              -ExpectedHash ([string]$SidecarInfo.ExpectedHash).ToLowerInvariant() `
                              -Algorithm $SidecarInfo.Algorithm -Reason $null
    }

    # --- 4. nothing to compare against --------------------------------------
    return New-Comparator -Source 'none' -ExpectedHash $null -Algorithm $null -Reason $null
}
