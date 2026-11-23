# Screen-captures the top-left corner of the WoW client window and decodes the
# WoWForeverGPT pixel strip (see Codec.lua in the addon). Prints one JSON line per
# new message to stdout. Started by bridge.js; can also be run by hand.
#
#   capture.ps1 -TestImage strip.png    decode a PNG once and exit (used by tests)

param(
  [int]$Cell = 4,
  [int]$Cells = 200,
  [int]$MaxRows = 48,
  [int]$IntervalMs = 250,
  [string]$ProcessName = "Wow",
  [string]$ClientFolder = "",
  [string]$TestImage = ""
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class CapWin {
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
}
"@
[void][CapWin]::SetProcessDPIAware()

# 일부 클라이언트의 UI 배율은 4 UI 단위를 정확히 4 화면 픽셀로 만들지 않는다.
# 짧은 헤더는 우연히 읽혀도 긴 본문에서는 오차가 누적되므로 실제 칸 간격을 찾는다.
# 탐색은 C#에서 수행하고, 전체 길이와 Fletcher 검증값이 모두 맞는 간격만 채택한다.
# 검사 실패 데이터를 복구하거나 검증을 생략하지 않으며 화면 이미지는 저장하지 않는다.
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
public static class StripPitch {
  static bool Valid(Bitmap bmp, int cells, int rows, double pitch) {
    int acc = 0, bits = 0, count = 0, need = 6, len = 0, s1 = 0, s2 = 0;
    int[] bytes = new int[cells * rows * 3 / 8];
    for (int i = 0; i < cells * rows; i++) {
      int x = (int)Math.Floor((i % cells + 0.5) * pitch);
      int y = (int)Math.Floor((i / cells + 0.5) * pitch);
      if (x >= bmp.Width || y >= bmp.Height) return false;
      Color p = bmp.GetPixel(x, y);
      acc = (acc << 3) | (p.R >= 128 ? 4 : 0) | (p.G >= 128 ? 2 : 0) | (p.B >= 128 ? 1 : 0);
      bits += 3;
      while (bits >= 8) {
        int b = (acc >> (bits - 8)) & 255;
        bytes[count++] = b;
        bits -= 8;
        acc &= (1 << bits) - 1;
        if (count == 2 && (bytes[0] != 0xC7 || bytes[1] != 0x1A)) return false;
        if (count == 6) {
          len = bytes[4] * 256 + bytes[5]; need = len + 8;
          if (need > bytes.Length) return false;
        }
        if (count >= need) {
          for (int k = 2; k < len + 6; k++) { s1 = (s1 + bytes[k]) % 255; s2 = (s2 + s1) % 255; }
          return bytes[len + 6] == s1 && bytes[len + 7] == s2;
        }
      }
    }
    return false;
  }
  public static double Find(Bitmap bmp, int cells, int rows, double nominal) {
    // 가로 200칸의 누적 오차를 1픽셀 이내로 제한하도록 1/512픽셀 간격으로 탐색한다.
    // 가까운 값부터 검사해 흔한 소수점 배율은 빨리 찾고, 이후에는 찾은 값을 재사용한다.
    for (int step = 1; step <= (int)Math.Ceiling(nominal * 0.1 * 512); step++) {
      double delta = step / 512.0;
      if (Valid(bmp, cells, rows, nominal + delta)) return nominal + delta;
      if (Valid(bmp, cells, rows, nominal - delta)) return nominal - delta;
    }
    return 0;
  }
}
"@

function Emit($obj) {
  [Console]::Out.WriteLine((ConvertTo-Json -Compress -InputObject $obj))
  [Console]::Out.Flush()
}

# Each channel is either fully on or off, so anything past mid-grey counts as on.
function CellValue($bmp, [int]$c, [int]$r, [double]$pitch) {
  $x = [int][Math]::Floor(($c + 0.5) * $pitch)
  $y = [int][Math]::Floor(($r + 0.5) * $pitch)
  if ($x -ge $bmp.Width -or $y -ge $bmp.Height) { return -1 }
  $px = $bmp.GetPixel($x, $y)
  $v = 0
  if ($px.R -ge 128) { $v += 4 }
  if ($px.G -ge 128) { $v += 2 }
  if ($px.B -ge 128) { $v += 1 }
  return $v
}

function Decode($bmp, [double]$pitch = $Cell) {
  $acc = 0; $nbits = 0
  $bytes = New-Object System.Collections.Generic.List[int]
  $needed = 6
  $total = $Cells * $MaxRows
  for ($i = 0; $i -lt $total; $i++) {
    $c = $i % $Cells
    $r = [int][Math]::Floor($i / $Cells)
    $v = CellValue $bmp $c $r $pitch
    if ($v -lt 0) { return @{ error = "truncated" } }
    $acc = ($acc -shl 3) -bor $v
    $nbits += 3
    while ($nbits -ge 8) {
      $b = ($acc -shr ($nbits - 8)) -band 0xFF
      $bytes.Add($b)
      $nbits -= 8
      $acc = $acc -band ((1 -shl $nbits) - 1)
      if ($bytes.Count -eq 2) {
        if ($bytes[0] -ne 0xC7 -or $bytes[1] -ne 0x1A) { return $null }
      }
      if ($bytes.Count -eq 6) {
        $len = ($bytes[4] * 256) + $bytes[5]
        $needed = 8 + $len
        if ($needed -gt [int]($total * 3 / 8)) { return @{ error = "length" } }
      }
      if ($bytes.Count -ge $needed) { break }
    }
    if ($bytes.Count -ge $needed) { break }
  }
  if ($bytes.Count -lt $needed) { return @{ error = "truncated" } }
  $len = ($bytes[4] * 256) + $bytes[5]
  $s1 = 0; $s2 = 0
  for ($k = 2; $k -lt (6 + $len); $k++) {
    $s1 = ($s1 + $bytes[$k]) % 255
    $s2 = ($s2 + $s1) % 255
  }
  if ($bytes[6 + $len] -ne $s1 -or $bytes[7 + $len] -ne $s2) {
    # 질문 원문은 로그에 남기지 않고 패킷 크기와 검증값만 기록한다.
    # 길이가 계속 0으로 감지되면 빈 셀/다른 화면을 신호로 오인한 것인지 구분할 수 있다.
    return @{ error = "checksum"; length = $len; packet = (($bytes[2] * 256) + $bytes[3]); expected = "$s1,$s2"; actual = "$($bytes[6 + $len]),$($bytes[7 + $len])" }
  }
  $payload = New-Object byte[] $len
  for ($k = 0; $k -lt $len; $k++) { $payload[$k] = [byte]$bytes[6 + $k] }
  return @{ id = (($bytes[2] * 256) + $bytes[3]); text = [Text.Encoding]::UTF8.GetString($payload) }
}

$script:stripPitch = [double]$Cell
$script:lastPitchSearch = [DateTime]::MinValue
function DecodeCalibrated($bmp) {
  $msg = Decode $bmp $script:stripPitch
  if ($msg -and -not $msg.error) { return $msg }
  # 정상 프레임은 기존처럼 한 번만 읽는다. 신호 헤더가 감지된 실패 프레임만
  # 보정해 일반 게임 화면을 매 틱 탐색하는 비용과 오인 가능성을 줄인다.
  # UI/모니터 배율이 바뀌면 헤더부터 어긋날 수 있다. 헤더가 읽힌 실패만 보정하던
  # 경로는 이 경우 영구히 복구하지 못했다. 무신호 탐색은 3초에 한 번으로 제한하고,
  # 전체 길이와 Fletcher 체크섬이 맞는 후보만 채택한다. 화면/질문 원문은 기록하지 않는다.
  if (($msg -and $msg.error) -or ([DateTime]::UtcNow - $script:lastPitchSearch).TotalSeconds -ge 3) {
    $script:lastPitchSearch = [DateTime]::UtcNow
    $found = [StripPitch]::Find($bmp, $Cells, $MaxRows, $Cell)
    if ($found -gt 0) {
      $script:stripPitch = $found
      if ($TestImage -eq "") { Emit @{ info = "pixel pitch calibrated: $found (nominal $Cell)" } }
      return Decode $bmp $found
    }
  }
  return $msg
}

if ($TestImage -ne "") {
  $bmp = [System.Drawing.Bitmap]::FromFile($TestImage)
  $msg = DecodeCalibrated $bmp
  $bmp.Dispose()
  if ($msg) { Emit $msg } else { Emit @{ error = "no valid strip in image" } }
  exit 0
}

$lastId = -1
$lastWarn = [DateTime]::MinValue
$proc = $null
$w = [int][Math]::Ceiling($Cells * $Cell * 1.1)
$h = [int][Math]::Ceiling($MaxRows * $Cell * 1.1)
while ($true) {
  if (-not $proc -or $proc.HasExited) {
    # Retail's exe is also Wow.exe: skip a game running from another client folder.
    $proc = Get-Process $ProcessName -ErrorAction SilentlyContinue | Where-Object {
      $_.MainWindowHandle -ne 0 -and (-not $ClientFolder -or -not $_.Path -or (Split-Path -Leaf (Split-Path -Parent $_.Path)) -eq $ClientFolder)
    } | Select-Object -First 1
    if (-not $proc) {
      Emit @{ info = "waiting for $ProcessName window$(if ($ClientFolder) { " in $ClientFolder" })" }
      Start-Sleep -Seconds 3
      continue
    }
    Emit @{ info = "attached to '$($proc.MainWindowTitle)' (pid $($proc.Id))" }
  }
  # 게임이 창을 재생성한 경우 캐싱된 핸들 대신 현재 핸들과 위치를 사용한다.
  $proc.Refresh()
  $hwnd = $proc.MainWindowHandle
  if ([CapWin]::IsIconic($hwnd)) { Start-Sleep -Milliseconds 1000; continue }
  $pt = New-Object CapWin+POINT
  [void][CapWin]::ClientToScreen($hwnd, [ref]$pt)
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $ok = $true
  try { $g.CopyFromScreen($pt.X, $pt.Y, 0, 0, $bmp.Size) } catch { $ok = $false }
  $g.Dispose()
  if ($ok) {
    $msg = DecodeCalibrated $bmp
    if ($msg -and $msg.error) {
      # Magic matched but the frame didn't validate: say so, at most every 5 s.
      if (([DateTime]::Now - $lastWarn).TotalSeconds -ge 5) {
        $lastWarn = [DateTime]::Now
        Emit @{ warn = "strip seen but rejected: $($msg.error) (packet=$($msg.packet), length=$($msg.length), expected=$($msg.expected), actual=$($msg.actual))" }
      }
    } elseif ($msg) {
      $key = "$($msg.id):$($msg.text)"
      if ($key -ne $lastId) {
        $lastId = $key
        Emit $msg
      }
    }
  }
  $bmp.Dispose()
  Start-Sleep -Milliseconds $IntervalMs
}
