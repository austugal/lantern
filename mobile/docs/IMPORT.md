# Continue on your computer

The download contains source plus a Git bundle of the completed local work branch. It does not require Copilot credits. Preserve the existing Copilot worktree; clone the bundle into a different directory.

From the extracted archive directory, in PowerShell:

```powershell
git clone .\lantern-mobile-mvp.bundle lantern-completed
cd lantern-completed
git remote set-url origin https://github.com/austugal/lantern.git
git push -u origin lantern-mobile-mvp
```

Authenticate using your normal GitHub credentials if prompted. Never paste tokens into chat. After the push, the workflow in `.github/workflows/flutter.yml` starts automatically. Its artifacts include an Android debug APK and an iOS simulator app when the respective builds pass.

The bundle includes the base commit from main and the new branch. It does not include or overwrite the unpushed files in your original Windows Copilot worktree.

To permit completion directly through ChatGPT, the GitHub integration must have repository write access; being able to read the repository or seeing administrator permissions for the account is insufficient. The integration's attempted branch creation returned `403 Resource not accessible by integration`.
