function Get-HistoryFreeRepositoryInventory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root)

    if (-not ('Caldova.RepositoryObjectInspection' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
namespace Caldova {
    public static class RepositoryObjectInspection {
        [StructLayout(LayoutKind.Sequential)]
        struct Information {
            public uint Attributes;
            public System.Runtime.InteropServices.ComTypes.FILETIME Creation, Access, Write;
            public uint Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
        }
        [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
        struct Stream {
            public long Size;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst=296)] public string Name;
        }
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        static extern IntPtr CreateFile(string path, uint access, uint share, IntPtr security, uint creation, uint flags, IntPtr template);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern bool GetFileInformationByHandle(IntPtr handle, out Information information);
        [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        static extern IntPtr FindFirstStreamW(string path, int level, out Stream data, uint flags);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        static extern bool FindNextStreamW(IntPtr handle, out Stream data);
        [DllImport("kernel32.dll")] static extern bool FindClose(IntPtr handle);
        public static string Inspect(string path) {
            var invalid = new IntPtr(-1);
            var handle = CreateFile(path, 0, 7, IntPtr.Zero, 3, 0x02200000, IntPtr.Zero);
            if (handle == invalid) throw new Win32Exception(Marshal.GetLastWin32Error());
            try {
                Information info;
                if (!GetFileInformationByHandle(handle, out info)) throw new Win32Exception(Marshal.GetLastWin32Error());
                if ((info.Attributes & 0x400) != 0 || ((info.Attributes & 0x10) == 0 && info.Links != 1)) return "LinkedObject";
            } finally { CloseHandle(handle); }
            Stream stream;
            handle = FindFirstStreamW(path, 0, out stream, 0);
            if (handle == invalid) {
                int error = Marshal.GetLastWin32Error();
                if (error == 38) return null;
                throw new Win32Exception(error);
            }
            try {
                do {
                    if (stream.Name != "::$DATA") return "AlternateStream";
                } while (FindNextStreamW(handle, out stream));
                if (Marshal.GetLastWin32Error() != 38) throw new Win32Exception(Marshal.GetLastWin32Error());
            } finally { FindClose(handle); }
            return null;
        }
    }
}
'@
    }
    $full = [IO.Path]::GetFullPath($Root)
    if ($full -ceq [IO.Path]::GetPathRoot($full)) { throw 'A volume root is not a history-free repository input.' }
    $full = $full.TrimEnd('\')
    if ($Root -notmatch '^[A-Za-z]:\\' -or $Root.Substring(2).Contains(':') -or
        $Root -match '(?:^|\\)(?:\.{1,2}|[^\\]*[. ])(?:\\|$)') { throw 'Invalid history-free root.' }
    $cursor = $full
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Linked history-free ancestor.' }
        $parent = Split-Path $cursor -Parent
        if ($parent -ceq $cursor) { break }
        $cursor = $parent
    }
    if (-not (Test-Path -LiteralPath $full -PathType Container)) { throw 'History-free input is not a directory.' }
    $files = [Collections.Generic.List[string]]::new()
    $directories = [Collections.Generic.List[string]]::new()
    $findings = [Collections.Generic.List[object]]::new()
    $pending = [Collections.Generic.Queue[string]]::new()
    $pending.Enqueue($full)
    $rootFinding = [Caldova.RepositoryObjectInspection]::Inspect($full)
    if ($rootFinding) { $findings.Add([pscustomobject]@{ category = $rootFinding; path = '.' }) }
    while ($pending.Count -gt 0) {
        foreach ($item in Get-ChildItem -LiteralPath $pending.Dequeue() -Force -ErrorAction Stop) {
            $relative = $item.FullName.Substring($full.Length + 1).Replace('\', '/')
            if ($item.PSIsContainer) { $directories.Add($relative) } else { $files.Add($relative) }
            if ($item.Name -match '[. ]$|:|[\x00-\x1f]' -or $item.Name -in @('.', '..')) {
                $findings.Add([pscustomobject]@{ category = 'UnsafePath'; path = $relative })
                continue
            }
            $category = if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
                ($null -ne $item.PSObject.Properties['LinkType'] -and $item.LinkType)) { 'LinkedObject' }
            else { [Caldova.RepositoryObjectInspection]::Inspect($item.FullName) }
            if ($category) {
                $findings.Add([pscustomobject]@{ category = $category; path = $relative })
                continue
            }
            if ($item.Name -ieq '.git') {
                $findings.Add([pscustomobject]@{ category = 'GitMetadata'; path = $relative })
                continue
            }
            if ($item.PSIsContainer) { $pending.Enqueue($item.FullName) }
        }
    }
    [pscustomobject]@{ files = @($files); directories = @($directories); findings = @($findings) }
}
