"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[803],{7248:(e,n,t)=>{t.r(n),t.d(n,{assets:()=>a,contentTitle:()=>s,default:()=>h,frontMatter:()=>r,metadata:()=>i,toc:()=>c});const i=JSON.parse('{"id":"installation","title":"Installation","description":"Method #1 - RepoToRoblox","source":"@site/docs/installation.md","sourceDirName":".","slug":"/installation","permalink":"/Janitor/docs/installation","draft":false,"unlisted":false,"editUrl":"https://github.com/howmanysmall/Janitor/edit/main/docs/installation.md","tags":[],"version":"current","sidebarPosition":2,"frontMatter":{"sidebar_position":2},"sidebar":"defaultSidebar","previous":{"title":"Getting Started with Janitor","permalink":"/Janitor/docs/intro"},"next":{"title":"Why use Janitor?","permalink":"/Janitor/docs/why-use-janitor"}}');var o=t(4848),l=t(8453);const r={sidebar_position:2},s="Installation",a={},c=[{value:"Method #1 - RepoToRoblox",id:"method-1---repotoroblox",level:3},{value:"Method #2 - HttpService",id:"method-2---httpservice",level:3},{value:"Method 3 - Manual",id:"method-3---manual",level:3},{value:"Method 4 - Wally",id:"method-4---wally",level:3},{value:"Next",id:"next",level:2}];function d(e){const n={a:"a",code:"code",em:"em",h1:"h1",h2:"h2",h3:"h3",header:"header",img:"img",li:"li",ol:"ol",p:"p",pre:"pre",ul:"ul",...(0,l.R)(),...e.components};return(0,o.jsxs)(o.Fragment,{children:[(0,o.jsx)(n.header,{children:(0,o.jsx)(n.h1,{id:"installation",children:"Installation"})}),"\n",(0,o.jsx)(n.h3,{id:"method-1---repotoroblox",children:"Method #1 - RepoToRoblox"}),"\n",(0,o.jsxs)(n.p,{children:["Using Boatbomber's ",(0,o.jsx)(n.a,{href:"https://devforum.roblox.com/t/repotoroblox-simple-and-quick-github-cloning-into-your-explorer/1000272",children:"RepoToRoblox"})," plugin is the easiest way to install in Studio."]}),"\n",(0,o.jsxs)(n.ol,{children:["\n",(0,o.jsxs)(n.li,{children:["In the RepoToRoblox widget, enter ",(0,o.jsx)(n.code,{children:"howmanysmall"})," as the Owner and ",(0,o.jsx)(n.code,{children:"Janitor"})," as the Repo."]}),"\n",(0,o.jsx)(n.li,{children:"Click the Clone Repo button."}),"\n"]}),"\n",(0,o.jsx)(n.p,{children:(0,o.jsx)(n.img,{src:"https://i.imgur.com/mOYl9T1.png",alt:"Widget"})}),"\n",(0,o.jsx)(n.h3,{id:"method-2---httpservice",children:"Method #2 - HttpService"}),"\n",(0,o.jsxs)(n.p,{children:["This method uses ",(0,o.jsx)(n.code,{children:"HttpService"})," to install Janitor."]}),"\n",(0,o.jsxs)(n.ol,{children:["\n",(0,o.jsx)(n.li,{children:"In Roblox Studio, paste the following command into your command bar."}),"\n",(0,o.jsx)(n.li,{children:"Run the following command:"}),"\n"]}),"\n",(0,o.jsx)("textarea",{readonly:!0,rows:"5",onClick:e=>e.target.select(),style:{width:"100%"},children:'local ReplicatedStorage = game:GetService("ReplicatedStorage")\nlocal HttpService = game:GetService("HttpService")\nlocal HttpEnabled = HttpService.HttpEnabled\nHttpService.HttpEnabled = true\nlocal function RequestAsync(RequestDictionary)\n  return HttpService:RequestAsync(RequestDictionary)\nend\nlocal function GetAsync(Url, Headers)\n  Headers["cache-control"] = "no-cache"\n  local Success, ResponseDictionary = pcall(RequestAsync, {\n      Headers = Headers;\n      Method = "GET";\n      Url = Url;\n  })\n  if Success then\n      if ResponseDictionary.Success then\n          return ResponseDictionary.Body\n      else\n          return false, string.format("HTTP %*: %*", ResponseDictionary.StatusCode, ResponseDictionary.StatusMessage)\n      end\n  else\n      return false, ResponseDictionary\n  end\nend\nlocal function Initify(Root)\n  local InitFile = Root:FindFirstChild("init")\n      or Root:FindFirstChild("init.luau") or Root:FindFirstChild("init.client.luau") or Root:FindFirstChild("init.server.luau")\n      or Root:FindFirstChild("init.luau") or Root:FindFirstChild("init.client.luau") or Root:FindFirstChild("init.server.lua")\n  if InitFile then\n      InitFile.Name = Root.Name\n      InitFile.Parent = Root.Parent\n      for _, Child in Root:GetChildren() do\n          Child.Parent = InitFile\n      end\n      Root:Destroy()\n      Root = InitFile\n  end\n  for _, Child in Root:GetChildren() do\n      Initify(Child)\n  end\n  return Root\nend\nlocal FilesList = HttpService:JSONDecode(assert(GetAsync(\n  "https://api.github.com/repos/howmanysmall/Janitor/contents/src",\n  {accept = "application/vnd.github.v3+json"}\n)))\nlocal Janitor = Instance.new("Folder")\nJanitor.Name = "Janitor"\nfor _, FileData in FilesList do\n  local ModuleScript = Instance.new("ModuleScript")\n  ModuleScript.Name = tostring(string.match(FileData.name, "(%w+)%.luau?"))\n  local Success, Source = GetAsync(FileData.download_url, {})\n  if not Success then\n      ModuleScript.Source = string.format("-- %*", tostring(Source))\n  else\n      ModuleScript.Source = tostring(Success)\n  end\n  ModuleScript.Parent = Janitor\nend\nJanitor.Parent = ReplicatedStorage\nInitify(Janitor)\nHttpService.HttpEnabled = HttpEnabled'}),"\n",(0,o.jsx)(n.h3,{id:"method-3---manual",children:"Method 3 - Manual"}),"\n",(0,o.jsxs)(n.ol,{children:["\n",(0,o.jsxs)(n.li,{children:["Visit the ",(0,o.jsx)(n.a,{href:"https://github.com/howmanysmall/Janitor/releases",children:"latest release"})]}),"\n",(0,o.jsxs)(n.li,{children:["Under ",(0,o.jsx)(n.em,{children:"Assets"}),", click ",(0,o.jsx)(n.code,{children:"Janitor.rbxm"})]}),"\n",(0,o.jsxs)(n.li,{children:["\n",(0,o.jsxs)(n.ul,{children:["\n",(0,o.jsxs)(n.li,{children:["Using ",(0,o.jsx)(n.a,{href:"https://rojo.space/",children:"Rojo"}),"? Put the file into your game directly."]}),"\n",(0,o.jsx)(n.li,{children:"Using Roblox Studio? Drag the file onto the viewport. It should insert under Workspace."}),"\n"]}),"\n"]}),"\n"]}),"\n",(0,o.jsx)(n.h3,{id:"method-4---wally",children:"Method 4 - Wally"}),"\n",(0,o.jsxs)(n.ol,{children:["\n",(0,o.jsxs)(n.li,{children:["Setup ",(0,o.jsx)(n.a,{href:"https://wally.run/",children:"Wally"})," by using ",(0,o.jsx)(n.code,{children:"wally init"}),"."]}),"\n",(0,o.jsxs)(n.li,{children:["Add ",(0,o.jsx)(n.code,{children:"howmanysmall/Janitor"})," as a dependency."]}),"\n"]}),"\n",(0,o.jsx)(n.pre,{children:(0,o.jsx)(n.code,{className:"language-toml",children:'[dependencies]\nJanitor = "howmanysmall/janitor@^1.17.0"\n'})}),"\n",(0,o.jsx)(n.h2,{id:"next",children:"Next"}),"\n",(0,o.jsxs)(n.p,{children:["Now, check out the ",(0,o.jsx)(n.a,{href:"/api/Janitor",children:"API reference"}),"!"]})]})}function h(e={}){const{wrapper:n}={...(0,l.R)(),...e.components};return n?(0,o.jsx)(n,{...e,children:(0,o.jsx)(d,{...e})}):d(e)}},8453:(e,n,t)=>{t.d(n,{R:()=>r,x:()=>s});var i=t(6540);const o={},l=i.createContext(o);function r(e){const n=i.useContext(l);return i.useMemo((function(){return"function"==typeof e?e(n):{...n,...e}}),[n,e])}function s(e){let n;return n=e.disableParentContext?"function"==typeof e.components?e.components(o):e.components||o:r(e.components),i.createElement(l.Provider,{value:n},e.children)}}}]);