# Test script to isolate remote execution issue

Add-Type -AssemblyName System.Drawing, System.Windows.Forms

# Test 1: Simple class without typed properties
class TestApp1 {
    [string]$Name = "Test"
    
    TestApp1() {
        Write-Host "TestApp1 created successfully"
    }
}

# Test 2: Class with Windows Forms typed properties
class TestApp2 {
    [System.Windows.Forms.Form]$MainForm
    
    TestApp2() {
        Write-Host "TestApp2 created successfully"
        $this.MainForm = New-Object System.Windows.Forms.Form
    }
}

# Test execution
try {
    Write-Host "Testing simple class..."
    $app1 = [TestApp1]::new()
    
    Write-Host "Testing Windows Forms class..."
    $app2 = [TestApp2]::new()
    
    Write-Host "All tests passed!"
}
catch {
    Write-Error "Test failed: $_"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
}
