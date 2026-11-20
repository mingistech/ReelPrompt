import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var input: NSTextField!
    var status: NSTextField!
    var logView: NSTextView!
    var analyzeButton: NSButton!
    var chooseButton: NSButton!
    var resultsButton: NSButton!
    var cancelButton: NSButton!
    var task: Process?
    var selected: URL?
    var result: URL?
    var config: [String:String] = [:]
    var pipe: Pipe?
    var quality: NSPopUpButton!
    var progressBar: NSProgressIndicator!
    var progressText: NSTextField!
    var completionIcon: NSImageView!
    var outputBuffer = Data()
    var cancelRequested = false
    var settingsWindow: NSWindow?
    var folderLabel: NSTextField?
    var settingsMessage: NSTextField?
    var settingsButton: NSButton!
    var folderButton: NSButton?
    var copyingModel = false
    var downloadTask: Process?
    var downloadButton: NSButton?
    var downloadSpinner: NSProgressIndicator?
    var downloadLog = ""
    let modelRepository = "divinetribe/Huihui-Qwen3-VL-32B-Instruct-abliterated-4bit-mlx"
    let modelRevision = "72c71ea2a685c0ce489900890e73c691f871102a"
    let modelFolderKey = "modelStorageFolder"

    func activeModelURL() -> URL? {
        guard let original=config["model"] else { return nil }
        let originalURL=URL(fileURLWithPath:original)
        guard let folder=UserDefaults.standard.string(forKey:modelFolderKey) else { return originalURL }
        return URL(fileURLWithPath:folder, isDirectory:true).appendingPathComponent(originalURL.lastPathComponent, isDirectory:true)
    }
    func validModel(_ directory:URL) -> Bool {
        let fm=FileManager.default
        let index=directory.appendingPathComponent("model.safetensors.index.json")
        guard fm.fileExists(atPath:directory.appendingPathComponent("config.json").path),
              let data=try? Data(contentsOf:index),
              let json=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              let map=json["weight_map"] as? [String:String], !map.isEmpty else { return false }
        return Set(map.values).allSatisfy { fm.fileExists(atPath:directory.appendingPathComponent($0).path) }
    }
    @objc func showSettings() {
        if let w=settingsWindow { w.makeKeyAndOrderFront(nil); return }
        let w=NSWindow(contentRect:NSRect(x:0,y:0,width:700,height:345),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        w.title="Settings"; w.isReleasedWhenClosed=false
        let v=w.contentView!
        let title=NSTextField(labelWithString:"Model storage folder"); title.frame=NSRect(x:24,y:301,width:650,height:26); title.font = .systemFont(ofSize:18,weight:.semibold); v.addSubview(title)
        let info=NSTextField(wrappingLabelWithString:"Choose where the app stores its model. If needed, the current model is copied to the selected folder; the original is kept."); info.frame=NSRect(x:24,y:255,width:650,height:38); v.addSubview(info)
        let path=NSTextField(labelWithString:activeModelURL()?.deletingLastPathComponent().path ?? "Not configured"); path.frame=NSRect(x:190,y:218,width:480,height:24); path.lineBreakMode = .byTruncatingMiddle; v.addSubview(path); folderLabel=path
        let message=NSTextField(wrappingLabelWithString:""); message.frame=NSRect(x:190,y:74,width:450,height:40); v.addSubview(message); settingsMessage=message
        let button=NSButton(title:"Choose Folder…",target:self,action:#selector(chooseModelFolder)); button.frame=NSRect(x:24,y:213,width:155,height:32); v.addSubview(button); folderButton=button
        let divider=NSBox(frame:NSRect(x:24,y:194,width:650,height:1)); divider.boxType = .separator; v.addSubview(divider)
        let modelTitle=NSTextField(labelWithString:"Model download"); modelTitle.frame=NSRect(x:24,y:161,width:500,height:24); modelTitle.font = .systemFont(ofSize:18,weight:.semibold); v.addSubview(modelTitle)
        let modelInfo=NSTextField(labelWithString:"Huihui Qwen3-VL 32B · 4-bit MLX · approximately 19.6 GB"); modelInfo.frame=NSRect(x:24,y:128,width:640,height:24); v.addSubview(modelInfo)
        let download=NSButton(title:"Download Model",target:self,action:#selector(downloadModel)); download.frame=NSRect(x:24,y:82,width:155,height:32); v.addSubview(download); downloadButton=download
        let spinner=NSProgressIndicator(frame:NSRect(x:650,y:88,width:20,height:20)); spinner.style = .spinning; spinner.isDisplayedWhenStopped=false; v.addSubview(spinner); downloadSpinner=spinner
        message.stringValue=activeModelURL().map { validModel($0) } == true ? "Model is installed and ready." : "Model is missing. Choose a folder and download it."
        settingsWindow=w; w.center(); w.makeKeyAndOrderFront(nil)
    }
    @objc func chooseModelFolder() {
        guard !copyingModel, downloadTask == nil, task == nil, let source=activeModelURL() else { settingsMessage?.stringValue="Wait for analysis to finish before changing folders."; return }
        let panel=NSOpenPanel(); panel.canChooseDirectories=true; panel.canChooseFiles=false; panel.canCreateDirectories=true; panel.allowsMultipleSelection=false
        panel.message="Choose a folder for the model. The current model will be copied there if needed."
        guard panel.runModal() == .OK, let selectedFolder=panel.url else { return }
        let folder=selectedFolder.standardizedFileURL
        let destination=folder.appendingPathComponent(source.lastPathComponent,isDirectory:true)
        let resolvedFolder=folder.resolvingSymlinksInPath().path
        let resolvedSource=source.resolvingSymlinksInPath().path
        if resolvedFolder == resolvedSource || resolvedFolder.hasPrefix(resolvedSource + "/") { settingsMessage?.stringValue="Choose a folder outside the current model folder."; return }
        if destination.standardizedFileURL == source.standardizedFileURL || validModel(destination) {
            UserDefaults.standard.set(folder.path,forKey:modelFolderKey); folderLabel?.stringValue=folder.path; settingsMessage?.stringValue="Model folder updated."; return
        }
        if FileManager.default.fileExists(atPath:destination.path) { settingsMessage?.stringValue="A model folder already exists there but is incomplete. Choose another folder."; return }
        guard validModel(source) else { UserDefaults.standard.set(folder.path,forKey:modelFolderKey); folderLabel?.stringValue=folder.path; settingsMessage?.stringValue="Folder selected. Click Download Model to install it."; return }
        copyingModel=true; folderButton?.isEnabled=false; settingsButton.isEnabled=false; analyzeButton.isEnabled=false; chooseButton.isEnabled=false
        settingsMessage?.stringValue="Copying model… This may take a while. Keep the app open."
        let temporary=folder.appendingPathComponent(".video-prompt-copy-"+UUID().uuidString,isDirectory:true)
        DispatchQueue.global(qos:.userInitiated).async {
            var errorMessage:String?
            do {
                try FileManager.default.copyItem(at:source,to:temporary)
                guard self.validModel(temporary) else { throw NSError(domain:"ModelStorage",code:1,userInfo:[NSLocalizedDescriptionKey:"The copied model is incomplete."]) }
                try FileManager.default.moveItem(at:temporary,to:destination)
            } catch { errorMessage=error.localizedDescription; try? FileManager.default.removeItem(at:temporary) }
            DispatchQueue.main.async {
                self.copyingModel=false; self.folderButton?.isEnabled=true; self.settingsButton.isEnabled=true; self.analyzeButton.isEnabled=self.selected != nil; self.chooseButton.isEnabled=true
                if let errorMessage=errorMessage { self.settingsMessage?.stringValue="Could not copy model: \(errorMessage)" }
                else { UserDefaults.standard.set(folder.path,forKey:self.modelFolderKey); self.folderLabel?.stringValue=folder.path; self.settingsMessage?.stringValue="Model folder updated. Original copy kept." }
            }
        }
    }
    @objc func downloadModel() {
        guard !copyingModel, downloadTask == nil, task == nil, let destination=activeModelURL(), let python=config["python"] else { settingsMessage?.stringValue="Wait for the current operation to finish."; return }
        if validModel(destination) { settingsMessage?.stringValue="Model is already installed and ready."; return }
        let fm=FileManager.default
        if fm.fileExists(atPath:destination.path) { settingsMessage?.stringValue="An incomplete model folder already exists. Choose another folder."; return }
        let folder=destination.deletingLastPathComponent()
        let staging=folder.appendingPathComponent(".reelprompt-huihui-download",isDirectory:true)
        let cli=URL(fileURLWithPath:python)
        guard fm.isExecutableFile(atPath:cli.path) else { settingsMessage?.stringValue="Download tool is unavailable. Reinstall the app runtime."; return }
        let process=Process(); let output=Pipe(); downloadLog=""
        process.executableURL=cli
        process.arguments=["-B","-c","from huggingface_hub.cli.hf import main; main()","download",modelRepository,"--revision",modelRevision,"--local-dir",staging.path]
        var env=ProcessInfo.processInfo.environment; env.removeValue(forKey:"HF_HUB_OFFLINE"); env.removeValue(forKey:"TRANSFORMERS_OFFLINE"); process.environment=env
        process.standardOutput=output; process.standardError=output
        output.fileHandleForReading.readabilityHandler={ [weak self] handle in
            let data=handle.availableData
            if data.isEmpty { handle.readabilityHandler=nil; return }
            let chunk=String(decoding:data,as:UTF8.self)
            DispatchQueue.main.async { self?.downloadLog=String(((self?.downloadLog ?? "")+chunk).suffix(4000)) }
        }
        process.terminationHandler={ [weak self] proc in
            DispatchQueue.main.async {
                guard let self=self else { return }
                self.downloadTask=nil; self.downloadSpinner?.stopAnimation(nil); self.folderButton?.isEnabled=true; self.downloadButton?.isEnabled=true; self.settingsButton.isEnabled=true; self.chooseButton.isEnabled=true; self.analyzeButton.isEnabled=self.selected != nil
                guard proc.terminationStatus == 0 else { self.settingsMessage?.stringValue="Download failed. Check your connection and retry; partial files are kept."; self.append("Model download failed. " + self.downloadLog + "\n"); return }
                guard self.validModel(staging) else { self.settingsMessage?.stringValue="Download incomplete. Click Download Model to retry."; return }
                do { try fm.moveItem(at:staging,to:destination); self.settingsMessage?.stringValue="Download complete. Model is ready." }
                catch { self.settingsMessage?.stringValue="Could not install download: \(error.localizedDescription)" }
            }
        }
        do {
            try process.run(); downloadTask=process; downloadSpinner?.startAnimation(nil); folderButton?.isEnabled=false; downloadButton?.isEnabled=false; settingsButton.isEnabled=false; analyzeButton.isEnabled=false; chooseButton.isEnabled=false
            settingsMessage?.stringValue="Downloading model (about 19.6 GB)… Keep ReelPrompt open."
        } catch { settingsMessage?.stringValue="Could not start download: \(error.localizedDescription)" }
    }
    func applicationShouldTerminate(_ sender:NSApplication) -> NSApplication.TerminateReply {
        if copyingModel || downloadTask != nil { let a=NSAlert(); a.messageText="Model transfer in progress"; a.informativeText="Please wait for the transfer to finish before quitting."; a.runModal(); return .terminateCancel }
        return .terminateNow
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let root=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("ReelPrompt",isDirectory:true)
        let resources=Bundle.main.resourceURL!
        try? FileManager.default.createDirectory(at:root.appendingPathComponent("Models"),withIntermediateDirectories:true)
        config=["python":resources.appendingPathComponent("Python/bin/python3.12").path,
                "script":resources.appendingPathComponent("analyze.py").path,
                "model":root.appendingPathComponent("Models/Huihui-Qwen3-VL-32B-Instruct-abliterated-4bit-mlx").path,
                "output":root.appendingPathComponent("Results").path]
        let menu = NSMenu()
        let item = NSMenuItem(); menu.addItem(item)
        let appMenu = NSMenu(); item.submenu = appMenu
        let settingsItem=NSMenuItem(title:"Settings…",action:#selector(showSettings),keyEquivalent:",")
        settingsItem.target=self
        appMenu.addItem(withTitle:"About ReelPrompt",action:#selector(NSApplication.orderFrontStandardAboutPanel(_:)),keyEquivalent:"")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(settingsItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit ReelPrompt", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x:0,y:0,width:780,height:570), styleMask:[.titled,.closable,.miniaturizable,.resizable], backing:.buffered, defer:false)
        window.title = "ReelPrompt"
        window.minSize = NSSize(width:780,height:570)
        let view = window.contentView!
        func label(_ text:String,_ frame:NSRect,_ font:NSFont) -> NSTextField {
            let l = NSTextField(labelWithString:text); l.frame=frame; l.font=font; view.addSubview(l); return l
        }
        _ = label("ReelPrompt",NSRect(x:24,y:514,width:720,height:30),.systemFont(ofSize:24,weight:.semibold))
        _ = label("Runs on your Mac • Shot-by-shot analysis • No cloud upload",NSRect(x:24,y:484,width:720,height:24),.systemFont(ofSize:14))
        input = NSTextField(labelWithString:"Choose a video to begin"); input.frame=NSRect(x:24,y:437,width:550,height:24); input.lineBreakMode = .byTruncatingMiddle; view.addSubview(input)
        chooseButton=NSButton(title:"Choose Video…",target:self,action:#selector(choose)); chooseButton.frame=NSRect(x:590,y:432,width:166,height:32); view.addSubview(chooseButton)
        analyzeButton=NSButton(title:"Analyze Video",target:self,action:#selector(analyze)); analyzeButton.frame=NSRect(x:20,y:379,width:160,height:36); analyzeButton.bezelStyle = .rounded; analyzeButton.isEnabled=false; view.addSubview(analyzeButton)
        cancelButton=NSButton(title:"Cancel",target:self,action:#selector(cancel)); cancelButton.frame=NSRect(x:184,y:379,width:100,height:36); cancelButton.isEnabled=false; view.addSubview(cancelButton)
        quality=NSPopUpButton(frame:NSRect(x:304,y:384,width:270,height:26),pullsDown:false); quality.addItems(withTitles:["Huihui · Qwen3-VL 32B"]); view.addSubview(quality)
        settingsButton=NSButton(title:"Settings…",target:self,action:#selector(showSettings)); settingsButton.frame=NSRect(x:654,y:480,width:102,height:30); view.addSubview(settingsButton)
        resultsButton=NSButton(title:"Open Results",target:self,action:#selector(openResults)); resultsButton.frame=NSRect(x:590,y:379,width:166,height:36); resultsButton.isEnabled=false; view.addSubview(resultsButton)
        status=label("Ready. Videos up to 5 minutes; each run gets its own results folder.",NSRect(x:54,y:340,width:702,height:26),.systemFont(ofSize:13))
        completionIcon=NSImageView(frame:NSRect(x:25,y:344,width:20,height:20)); completionIcon.isHidden=true; view.addSubview(completionIcon)
        progressBar=NSProgressIndicator(frame:NSRect(x:24,y:319,width:658,height:14)); progressBar.style = .bar; progressBar.isIndeterminate=false; progressBar.minValue=0; progressBar.maxValue=100; progressBar.doubleValue=0; view.addSubview(progressBar)
        progressText=label("Ready",NSRect(x:690,y:315,width:66,height:22),.monospacedDigitSystemFont(ofSize:12,weight:.medium)); progressText.alignment = .right
        let scroll=NSScrollView(frame:NSRect(x:24,y:93,width:732,height:210)); scroll.hasVerticalScroller=true; scroll.borderType = .bezelBorder
        logView=NSTextView(frame:scroll.bounds); logView.isEditable=false; logView.font = .monospacedSystemFont(ofSize:14,weight:.regular); logView.textColor = .textColor; logView.backgroundColor = .textBackgroundColor; logView.textContainerInset = NSSize(width:10,height:10); scroll.documentView=logView; view.addSubview(scroll)
        _ = label("Saves one prompt per detected shot, detailed observations and reference frames.\nVisual analysis only; audio is not transcribed. No wardrobe override is applied.\nHuihui 32B runs locally. Review detected cuts and descriptions against your source.",NSRect(x:24,y:16,width:730,height:68),.systemFont(ofSize:12))
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
        if let folder=config["output"], let runs=try? FileManager.default.contentsOfDirectory(at:URL(fileURLWithPath:folder),includingPropertiesForKeys:nil), let latest=runs.sorted(by:{$0.lastPathComponent > $1.lastPathComponent}).first(where:{FileManager.default.fileExists(atPath:$0.appendingPathComponent("analysis.json").path)}) {
            result=latest; resultsButton.isEnabled=true; finishProgress(success:true, cancelled:false, previous:true)
            if let data=try? Data(contentsOf:latest.appendingPathComponent("analysis.json")), let info=try? JSONSerialization.jsonObject(with:data) as? [String:Any], let source=info["source"] as? String { selected=URL(fileURLWithPath:source) }
            append("Previous results may have used a different model. New analyses use Huihui 32B.\n")
        }
        if let selected = selected { input.stringValue=selected.path; analyzeButton.isEnabled=true }
    }
    func application(_ sender:NSApplication, openFile filename:String) -> Bool {
        selected=URL(fileURLWithPath:filename)
        input?.stringValue=filename; analyzeButton?.isEnabled=true
        return true
    }
    @objc func choose() {
        let panel=NSOpenPanel(); panel.canChooseDirectories=false; panel.allowsMultipleSelection=false
        panel.message="Choose a local video. It stays on your Mac."
        if panel.runModal() == .OK, let url=panel.url { selected=url; input.stringValue=url.path; analyzeButton.isEnabled=true; resetProgress() }
    }
    func append(_ s:String) { logView.textStorage?.append(NSAttributedString(string:s, attributes:[.foregroundColor:NSColor.textColor, .font:NSFont.monospacedSystemFont(ofSize:14,weight:.regular)])); logView.scrollToEndOfDocument(nil) }
    func resetProgress() {
        completionIcon.isHidden=true; status.textColor = .labelColor
        progressBar.stopAnimation(nil); progressBar.isIndeterminate=false; progressBar.doubleValue=0
        progressText.stringValue="Ready"; status.stringValue="Ready to analyze the selected video."
    }
    func showProgress(completed:Double,total:Double,stage:String) {
        guard task != nil, !cancelRequested else { return }
        completionIcon.isHidden=true; status.textColor = .labelColor
        status.stringValue=stage
        if total > 0 {
            progressBar.stopAnimation(nil); progressBar.isIndeterminate=false
            let percent=min(100,max(0,completed/total*100)); progressBar.doubleValue=percent
            progressText.stringValue="\(Int(percent))%"
        } else {
            progressBar.isIndeterminate=true; progressBar.startAnimation(nil); progressText.stringValue="Working"
        }
    }
    func finishProgress(success:Bool,cancelled:Bool,previous:Bool=false) {
        progressBar.stopAnimation(nil); progressBar.isIndeterminate=false
        completionIcon.isHidden=false
        let symbol=success ? "checkmark.circle.fill" : cancelled ? "minus.circle.fill" : "exclamationmark.circle.fill"
        completionIcon.image=NSImage(systemSymbolName:symbol,accessibilityDescription:success ? "Analysis completed successfully" : cancelled ? "Analysis cancelled" : "Analysis failed")
        completionIcon.contentTintColor=success ? .systemGreen : cancelled ? .systemOrange : .systemRed
        status.textColor=success ? .systemGreen : .labelColor
        if success {
            progressBar.doubleValue=100; progressText.stringValue="100%"
            status.stringValue=previous ? "Previous analysis finished. Open Results to view it." : "Finished! Your prompts and analysis are ready."
        } else {
            progressText.stringValue=cancelled ? "Cancelled" : "Failed"
            status.stringValue=cancelled ? "Analysis cancelled." : "Analysis failed. See the details below."
        }
    }
    func consumeOutput(_ data:Data) {
        outputBuffer.append(data)
        while let newline=outputBuffer.firstIndex(of:10) {
            let line=String(decoding:outputBuffer[..<newline],as:UTF8.self)
            outputBuffer.removeSubrange(...newline)
            let prefix="@@VIDEO_PROGRESS@@"
            if line.hasPrefix(prefix), let payload=line.dropFirst(prefix.count).data(using:.utf8),
               let event=(try? JSONSerialization.jsonObject(with:payload)) as? [String:Any],
               let completed=event["completed"] as? Double, let total=event["total"] as? Double, let stage=event["stage"] as? String {
                showProgress(completed:completed,total:total,stage:stage)
            } else { append(line+"\n") }
        }
    }
    @objc func analyze() {
        guard let video=selected, task == nil, !copyingModel, downloadTask == nil else { return }
        guard let python=config["python"], let script=config["script"], let model=config["model"], let output=config["output"] else { status.stringValue="App configuration is missing."; return }
        let chosenModel = activeModelURL()?.path ?? model
        guard FileManager.default.isExecutableFile(atPath:python), validModel(URL(fileURLWithPath:chosenModel)) else { status.stringValue="Model missing or incomplete. Open Settings to choose its folder."; return }
        let date=ISO8601DateFormatter().string(from:Date()).replacingOccurrences(of:":",with:"-")
        result=URL(fileURLWithPath:output).appendingPathComponent(date+"-"+UUID().uuidString.prefix(6))
        let process=Process(); let outputPipe=Pipe(); pipe=outputPipe
        process.executableURL=URL(fileURLWithPath:python)
        process.arguments=["-B","-u",script,video.path,"--model",chosenModel,"--output",result!.path]
        var env=ProcessInfo.processInfo.environment; env["HF_HUB_OFFLINE"]="1"; env["TRANSFORMERS_OFFLINE"]="1"; env["TOKENIZERS_PARALLELISM"]="false"; process.environment=env
        process.standardOutput=outputPipe; process.standardError=outputPipe
        outputBuffer.removeAll(); cancelRequested=false; resetProgress(); progressBar.isIndeterminate=true; progressBar.startAnimation(nil); progressText.stringValue="Working"
        logView.string=""; status.stringValue="Starting local analysis…"; settingsButton.isEnabled=false; quality.isEnabled=false; analyzeButton.isEnabled=false; chooseButton.isEnabled=false; resultsButton.isEnabled=false; cancelButton.isEnabled=true
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data=handle.availableData
            if data.isEmpty { handle.readabilityHandler=nil; return }
            DispatchQueue.main.async { self?.consumeOutput(data) }
        }
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self=self else { return }
                self.task=nil; self.settingsButton.isEnabled=true; self.quality.isEnabled=true; self.analyzeButton.isEnabled=true; self.chooseButton.isEnabled=true; self.cancelButton.isEnabled=false
                let ok=process.terminationStatus == 0 && !self.cancelRequested
                self.finishProgress(success:ok,cancelled:self.cancelRequested)
                self.resultsButton.isEnabled=ok
            }
        }
        do { try process.run(); task=process } catch { append("Could not start: \(error.localizedDescription)\n"); finishProgress(success:false,cancelled:false); settingsButton.isEnabled=true; quality.isEnabled=true; analyzeButton.isEnabled=true; chooseButton.isEnabled=true; cancelButton.isEnabled=false }
    }
    @objc func cancel() { cancelRequested=true; task?.terminate(); status.stringValue="Stopping…"; cancelButton.isEnabled=false }
    @objc func openResults() { if let result=result { NSWorkspace.shared.open(result) } }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification:Notification) { task?.terminate() }
}
let app=NSApplication.shared
let delegate=AppDelegate()
app.delegate=delegate
app.setActivationPolicy(.regular)
app.run()
