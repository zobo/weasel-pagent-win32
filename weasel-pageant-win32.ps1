$wa = new-object System.Diagnostics.Process
$wa.StartInfo.FileName = [System.IO.Path]::Combine($pwd, "helper.exe")
$wa.StartInfo.UseShellExecute = $false
$wa.StartInfo.RedirectStandardInput = $true
$wa.StartInfo.RedirectStandardOutput = $true
$wa.Start()
# read 'a' to init
$wa.StandardOutput.BaseStream.ReadByte()

$pip = new-object System.IO.Pipes.NamedPipeServerStream('openssh-ssh-agent', [System.IO.Pipes.PipeDirection]::InOut, 100)

while ($true)
{
  echo "Waiting for conn"
  $pip.WaitForConnection()

  while ($pip.IsConnected -eq $true)
  {
    #read header len
    echo "Reading req header"
    $br = new-object System.IO.BinaryReader($pip)
    $buf1 = $br.ReadBytes(4)
    if ($buf1.Count -eq 0)
    {
      echo "Got 0, end"
      break;
    }
    [array]::Reverse($buf1)
    $len = [System.BitConverter]::ToInt32($buf1, 0)
    echo "Got req header len $len reading body"
    # reverse it back
    [array]::Reverse($buf1)

    # check len!
    $buf2 = $br.ReadBytes($len)

    $wa.StandardInput.BaseStream.Write($buf1, 0, $buf1.Count)
    $wa.StandardInput.BaseStream.Write($buf2, 0, $buf2.Count)
    $wa.StandardInput.BaseStream.Flush()


    # read response!
    echo "Reading res header"
    $br = New-Object System.IO.BinaryReader($wa.StandardOutput.BaseStream)
    $buf1 = $br.ReadBytes(4)
    [array]::Reverse($buf1)
    $len = [System.BitConverter]::ToInt32($buf1, 0)
    echo "Got res header len $len reading body"
    # reverse it back
    [array]::Reverse($buf1)

    # check len!
    $buf2 = $br.ReadBytes($len)

    $pip.Write($buf1, 0, $buf1.Count)
    $pip.Write($buf2, 0, $buf2.Count)
    $pip.Flush()
  }
  # stop???

  $pip.Disconnect()
}

$pip.Close()
