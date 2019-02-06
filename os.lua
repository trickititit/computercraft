-----------------------ВСЯКИЕ ПОЛЕЗНОСТИ----------------------
local Args = {...}
os.loadAPI("System/API/context")
os.loadAPI("System/API/image")
os.loadAPI("System/API/windows")
os.loadAPI("System/API/config")
os.loadAPI("System/API/zip")

----------------------ПОДКЛЮЧЕНИЕ МОНИТОРА-----------------------
local function findPeripheral(whatToFind)
  local PeriList = peripheral.getNames()
  for i=1,#PeriList do
    if peripheral.getType(PeriList[i]) == whatToFind then
      return PeriList[i]
    end
  end
end

--ПОИСК ПЕРИФЕРИИ
local m = findPeripheral("monitor")
if Args[1] == "m" then
	if m ~= nil then
		m = peripheral.wrap(m)
		if Args[2] ~= nil then
			m.setTextScale(tonumber(Args[2]))
		end
		term.redirect(m)
	end
end

if not term.isColor() then error("This program will work only on advanced computer.") end

--[[ПОДМЕНА ФУНКЦИИ ЕРРОР
local standartErrorFunction = error
error = windows.error]]

----------------------ОБЪЯВЛЕНИЕ ПЕРЕМЕННЫХ----------------------
local xSize, ySize = term.getSize()
local centerX = math.floor(xSize/2)
local centerY = math.floor(ySize/2)
local appWidth = 10
local appHeight = 6

local countOfAppsByX = math.floor((xSize-2)/(appWidth+2))
local countOfAppsByY = math.floor((ySize-5)/(appHeight+1))
local countOfAppsOnDesktop = countOfAppsByX*countOfAppsByY

local countOfDesktops = nil

local startDisplayAllAppsFromX = centerX - math.floor((countOfAppsByX*(appWidth+2)-2)/2) + 1
local startDisplayAllAppsFromY = centerY - math.floor((countOfAppsByY*(appHeight+1)-1)/2) + 1

local currentDesktop = 1
local currentBackground = colors.lightBlue
local topBarColor = colors.gray

--МАССИВЫ ОБЪЕКТОВ
local Obj = {}
local ObjBottom = {}
local ObjApp = {}

local clipboardName = nil

local workPath = ""
local workPathHistory = {}

local hideFileFormat = true
local showHiddenFiles = true
local showSystemFolders = true

local Notification = nil
local sizeOfNotification = 24

local findedModem = windows.findPeripheral("modem")
local modem = nil
if findedModem then
	modem = peripheral.wrap(findedModem)
	if modem.isWireless() then
		rednet.open(findedModem)
	end
end

----------------------ОБЪЯВЛЕНИЕ ФУНКЦИЙ----------------------

--СОЗДАНИЕ ОБЪЕКТОВ ПРИЛОЖЕНИЙ
local function newObjApp(name,x1,y1,width,height,id,fileFormat)
	ObjApp[name]={}
	ObjApp[name]["x1"]=x1
	ObjApp[name]["y1"]=y1
	ObjApp[name]["x2"]=x1+width-1
	ObjApp[name]["y2"]=y1+height-1
	ObjApp[name]["id"]=id
	ObjApp[name]["fileFormat"]=fileFormat
end

--СОЗДАНИЕ ДРУГИХ ОБЪЕКТОВ
local function newObj(name,x1,y1,width,height)
	Obj[name]={}
	Obj[name]["x1"]=x1
	Obj[name]["y1"]=y1
	Obj[name]["x2"]=x1+width-1
	Obj[name]["y2"]=y1+height-1
end

--ОБЪЕКТОВ НИЖНИХ КНОПОК
local function newObjBottom(name,x1,y1,width,height)
	ObjBottom[name]={}
	ObjBottom[name]["x1"]=x1
	ObjBottom[name]["y1"]=y1
	ObjBottom[name]["x2"]=x1+width-1
	ObjBottom[name]["y2"]=y1+height-1
end

--ЗАГРУЗКА ФАЙЛОВ С ПАСТЕБИНА
local function pastebin(mode,paste,filename)
	if mode == "get" then
		local file = http.get("http://pastebin.com/raw.php?i="..paste)
		if file then
			file = file.readAll()
			h=fs.open(filename,"w")
			h.write(file)
			h.close()
		else
			windows.error("Failed to connect to pastebin.com")
		end
	elseif mode == "put" then	    
	    -- Read in the file
	    local file = fs.open(filename,"r")
	 	local sName = fs.getName( filename )
	    local sText = file.readAll()
	    file.close()
	    
	    -- POST the contents to pastebin
	    --write( "Connecting to pastebin.com... " )
	    local key = "0ec2eb25b6166c0c27a394ae118ad829"
	    local response = http.post(
	        "http://pastebin.com/api/api_post.php", 
	        "api_option=paste&"..
	        "api_dev_key="..key.."&"..
	        "api_paste_format=lua&"..
	        "api_paste_name="..textutils.urlEncode(sName).."&"..
	        "api_paste_code="..textutils.urlEncode(sText)
	    )
	        
	    if response then
	        local sResponse = response.readAll()
	        response.close()
	                
	        local sCode = string.match( sResponse, "[^/]+$" )

	        windows.attention({"Upload complete!"},{"Pastebin code is "..sCode.."\""})
	    else
	        windows.error("Failed to connect to pastebin.com")
	    end
	elseif mode == "run" then
		local file = http.get("http://pastebin.com/raw.php?i="..paste)
		if file then
			file = file.readAll()

			local func, err = loadstring(file)
	        if not func then
	            windows.error(err)
	            return
	        end
        	setfenv(func, getfenv())
	        local success, msg = pcall(func)
	        if not success then
	            windows.error(msg)
	        end
		else
			windows.error("Failed to connect to pastebin.com")
		end
	end
end

--ОГРАНИЧЕНИЕ ДЛИНЫ СТРОКИ
local function stringLimit(text,size)
	if string.len(text)<=size then return text end
	return string.sub(text,1,size-3).."..."
end

--ОГРАНИЧЕНИЕ ДЛИНЫ СТРОКИ
local function stringLimitFromStart(text,size)
	if string.len(text)<=size then return text end
	return "..."..string.sub(text,string.len(text)-size+4,string.len(text))
end

--ПРОСТОЕ ОТОБРАЖЕНИЕ ТЕКСТА ПО КООРДИНАТАМ
local function usualText(x,y,text)
	term.setCursorPos(x,y)
	term.write(text)
end

--РИСОВАНИЕ КВАДРАТА С ЗАЛИВКОЙ
local function square(x1,y1,width,height,color)
	local string = string.rep(" ",width)
	term.setBackgroundColor(color)
	for y=y1,(y1+height-1) do
		usualText(x1,y,string)
	end
end

--ЗАЛИВКА ЭКРАНА ЦВЕТОМ
local function clearScreen(color)
	term.setBackgroundColor(color)
	term.clear()
end

--ОЧИСТКА ЭКРАНА И УСТАНОВКА КУРСОРА НА 1, 1
local function prepareToExit()
	clearScreen(colors.black)
	term.setTextColor(colors.white)
	term.setCursorPos(1,1)
end

--ПЛАВНОЕ ВКЛЮЧЕНИЕ ЭКРАНА
local function fadeIn(time)
	clearScreen(colors.gray)
	sleep(time)
	clearScreen(colors.lightGray)
	sleep(time)
	clearScreen(colors.white)
	sleep(time)
end

--ПЛАВНОЕ ЗАТУХАНИЕ ЭКРАНА
local function fadeOut(time)
	clearScreen(colors.lightGray)
	sleep(time)
	clearScreen(colors.gray)
	sleep(time)
	clearScreen(colors.black)
	sleep(time)
	term.setCursorPos(1,1)
	term.setTextColor(colors.white)
end

--КОПИРОВАНИЕ ОБОЕВ РАБОЧЕГО СТОЛА В СИСТЕМНУЮ ПАПКУ
local function setWallpaper(path)
	fs.delete("System/OS/wallpaper.png")
	fs.copy(path,"System/OS/wallpaper.png")
end

--ЕСЛИ ФАЙЛ ТАКОЙ УЖЕ ЕСТЬ, ТО СПРОСИТЬ, НАДО ЛИ ЕГО ЗАМЕНЯТЬ
local function askForReplaceFile(path)
	if fs.exists(path) then
		local action = windows.select({"File already exists."},{"Do you want to replace it?"},{"No",colors.lightGray,colors.black},{"Yes",colors.lightBlue,colors.black})
		if action == "Yes" then
			return true
		else
			return false
		end
	end
	return true
end

--ФУНКЦИИ ДЛЯ РАБОТЫ С ФАЙЛАМИ И БУФЕРОМ ОБМЕНА
local function copy(whatToCopy)
	fs.delete("System/Clipboard.temp")
	fs.copy(whatToCopy,"System/Clipboard.temp")
end

local function paste(path,name)
	local agree = askForReplaceFile(path.."/"..name)
	if agree then
		fs.delete(path.."/"..name)
		fs.copy("System/Clipboard.temp",path.."/"..name)
	end
end

local function cut(path)
	fs.delete("System/Clipboard.temp")
	fs.copy(path,"System/Clipboard.temp")
	fs.delete(path)
end

local function rename(path,name,renameToName)
	local agree = askForReplaceFile(path.."/"..renameToName)
	if agree then
		fs.delete("System/OS/rename.temp")
		fs.move(path.."/"..name,"System/OS/rename.temp")
		fs.delete(path.."/"..renameToName)
		fs.move("System/OS/rename.temp",path.."/"..renameToName)
	end
end	

--ФУНКЦИЯ, ВЫЗЫВАЕМАЯ ПОСЛЕ ОКОНЧАНИЯ ЗАПУСКА ПРИЛОЖЕНИЯ
local function programFinished()
	local xCusor,yCursor = term.getCursorPos()
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	usualText(1,yCursor+1,"Press any key to quit.")

	while true do
		local event = os.pullEvent()
		if event == "monitor_touch" or event == "mouse_click" or event == "key" then break end
	end
end

--ВЕРХНЯЯ ПОЕБОНЬКА С ЧАСИКАМИ
local function topBar(topBarColor)
	local time = textutils.formatTime(os.time(),true)
	local string = " OS "..string.rep(" ",xSize-6-#time)..time.." S"
	term.setBackgroundColor(topBarColor)
	windows.colorText(1,1,string,colors.white)
	windows.colorText(6,1,"View",colors.lightGray)	
end
newObj("OS",1,1,4,1)
newObj("Search",xSize,1,1,1)
newObj("View",5,1,6,1)

--ФУНКЦИЯ ОТРИСОВКИ КОНКРЕТНО ВЫБРАННОГО ПРИЛОЖЕНИЯ ПО ИМЕНИ
local function drawKonkretnoApp(x,y,name,background,id)

	--СОЗДАНИЕ ОБЪЕКТА ПРИЛОЖЕНИЯ
	newObjApp(name,x,y,appWidth,appHeight,id,windows.getFileFormat(name))

	--РИСОВАНИЕ ИКОНКИ
	windows.drawOSIcon(x+2,y,workPath,name,ObjApp[name]["fileFormat"],showSystemFolders)

	--ОТРИСОВКА ИМЕНИ ПРИЛОЖЕНИЯ
	term.setBackgroundColor(background)
	if fs.isReadOnly(workPath.."/"..name) then
		term.setTextColor(colors.red)
	else
		term.setTextColor(colors.black)
	end
	if windows.isFileHidden(name) then
		term.setTextColor(colors.gray)
	end
	if hideFileFormat then
		name = windows.hideFileFormat(name)
	end
	name = stringLimit(name,10)
	usualText(math.floor(x+5-#name/2),y+5,name)

end

--ФУНКЦИЯ ОТРИСОВКИ ВООБЩЕ ВСЕХ ПРИЛОЖЕНИЙ НА РАБОЧЕМ СТОЛЕ
local function displayApps(workPath,currentDesktop,background)

	--ОБНУЛЕНИЕ МАССИВОВ
	ObjApp = {}
	ObjBottom = {}

	--ОТРИСОВКА ОБОЕВ
	--clearScreen(background)
	square(1,2,xSize,ySize-1,background)
	if fs.exists("System/OS/wallpaper.png") then
		image.draw(1,2,"System/OS/wallpaper.png")
	end

	--ОТРИСОВКА ВЕРХНЕЙ ШНЯГИ
	topBar(topBarColor)
	
	--ПОЛУЧИТЬ МАССИВ СО ВСЕМИ ФАЙЛАМИ/ПАПКАМИ
	local files = fs.list(workPath)
	--РЕОРГАНИЗОВАТЬ МАССИВ, ЧТОБ ПАПКИ БЫЛИ В НАЧАЛЕ
	files = windows.reorganizeFilesAndFolders(workPath,files,showHiddenFiles,showSystemFolders)

	local countOfFiles = #files
	countOfDesktops = math.ceil(countOfFiles/(countOfAppsByY*countOfAppsByX))

	--ОТРИСОВКА НИЖНЕГО ГОВНА
	local bottomButtonsStartX = nil
	if #workPathHistory == 0 then
		bottomButtonsStartX = centerX - math.floor((countOfDesktops*2+1)/2)
	else
		bottomButtonsStartX = centerX - math.floor((countOfDesktops*2-1)/2)
	end
	local bottomY = ySize-1
	for i=1,countOfDesktops do
		local bottomX = bottomButtonsStartX + i * 2
		if currentDesktop == i then
			paintutils.drawPixel(bottomX,bottomY,colors.white)
		else
			paintutils.drawPixel(bottomX,bottomY,colors.lightGray)
		end
		newObjBottom(i,bottomX,bottomY,1,1)
	end
	if #workPathHistory>0 then
		paintutils.drawPixel(bottomButtonsStartX,bottomY,colors.white)
		term.setTextColor(colors.black)
		usualText(bottomButtonsStartX,bottomY,"<")
		newObj("<",bottomButtonsStartX,bottomY,1,1)
	end

	--ОТРИСОВКА САМИХ ПРИЛОЖЕНИЙ
	local appCounter = 1 + currentDesktop * countOfAppsByY * countOfAppsByX - countOfAppsByY * countOfAppsByX
	for y = 1,countOfAppsByY do
		for x = 1,countOfAppsByX do
			if files[appCounter] ~= nil then
				drawKonkretnoApp(startDisplayAllAppsFromX+x*(appWidth+2)-(appWidth+2),startDisplayAllAppsFromY+y*(appHeight+1)-(appHeight+1),files[appCounter],background,appCounter)
				appCounter = appCounter + 1
			else
				break
			end
		end
	end

	--ОТРИСОВКА ОПОВЕЩЕНИЙ
	if Notification then
		local yNoti = 2
		local xNoti = math.floor(centerX - sizeOfNotification/2)
		windows.square(xNoti,yNoti,sizeOfNotification,2,colors.white)
		windows.colorText(xNoti+1,yNoti,windows.stringLimit("end",Notification["title"],sizeOfNotification-2),colors.gray)
		windows.colorText(xNoti+1,yNoti+1,windows.stringLimit("end",Notification["text"],sizeOfNotification-2),colors.lightGray)
		windows.colorText(xNoti+sizeOfNotification-1,yNoti,"x",colors.black)
		newObj("closeNoti",xNoti+sizeOfNotification-1,yNoti,1,1)
	end
end

local function askForMakingOSAsStartup()
	local action = windows.select({"Hello!"},{"Do you want to load OS","when computer starts?"},{"No",colors.lightGray,colors.black},{"Yes",colors.lightBlue,colors.black})
	if action == "Yes" then
		fs.copy("OS","startup")
		config.write("System/OS/startup.cfg","load when computer starts","true")
	else
		config.write("System/OS/startup.cfg","load when computer starts","false")
	end
end

--ЗАПУСТИТЬ ПРИЛОЖЕНИЕ С ДЕБАГГЕРОМ
local function launchFile(path,fileFormat,arguments)
	if fileFormat == nil then
		local success,err = loadfile(path)
		if success ~= nil then
			fadeOut(0)
			prepareToExit()
			if arguments == nil then
				shell.run(path)
			else
				shell.run(path.." "..arguments)
			end
			programFinished()
			fadeIn(0)
		else
			windows.error(err)
		end
	elseif fileFormat == ".png" then
		fadeOut(0)
		shell.run("Photoshop.app/main o "..path)
		fadeIn(0)
	elseif fileFormat == ".cfg" then
		fadeOut(0)
		shell.run("edit "..path)
		fadeIn(0)
	elseif fileFormat == ".app" then
		path = path.."/main"
		local success,err = loadfile(path)
		if success ~= nil then
			fadeOut(0)
			prepareToExit()
			if arguments == nil then
				shell.run(path)
			else
				shell.run(path.." "..arguments)
			end
			--programFinished()
			fadeIn(0)
		else
			windows.error(err)
		end
	end
end

--ПЕРЕЙТИ В УКАЗАННУЮ ДИРЕКТОРИЮ
local function gotoDirectory(path)
	workPathHistory[#workPathHistory+1] = workPath
	workPath = path
	currentDesktop = 1
end

----------------------------------СТАРТ ПРОГРАММЫ----------------------------------------

if fs.exists("System/OS/userdata.cfg") then
	showSystemFolders = windows.toboolean(config.read("System/OS/userdata.cfg","showSystemFolders"))
	showHiddenFiles = windows.toboolean(config.read("System/OS/userdata.cfg","showHiddenFiles"))
	hideFileFormat = windows.toboolean(config.read("System/OS/userdata.cfg","hideFileFormat"))
else
	config.write("System/OS/userdata.cfg","showSystemFolders","true")
	config.write("System/OS/userdata.cfg","showHiddenFiles","true")
	config.write("System/OS/userdata.cfg","hideFileFormat","true")
end

--РИСУЕМ ВООБЩЕ ВСЕ ПРИЛОЖЕНИЯ
displayApps(workPath,currentDesktop,currentBackground)

if not fs.exists("startup") then
	if not fs.exists("System/OS/startup.cfg") then
		askForMakingOSAsStartup()
		displayApps(workPath,currentDesktop,currentBackground)
	else
		local govno = config.read("System/OS/startup.cfg","load when computer starts")
		if govno ~= nil and govno ~= "false" then
			askForMakingOSAsStartup()
			displayApps(workPath,currentDesktop,currentBackground)
		end
	end
end

--НАЧАЛО ЕБЛИ МОЗГА
local exitFromProgram = false
while true do

	if exitFromProgram then break end

	--СЧЕТЧИК ПРИЛОЖЕНИЙ, НАЧИНАЯ С 1 НА ТЕКУЩЕМ РАБОЧЕМ СТОЛЕ
	local appCounter = 1 + currentDesktop * countOfAppsByY * countOfAppsByX - countOfAppsByY * countOfAppsByX

	local event,side,x,y = os.pullEvent()
	--ХУЙНЮШКА ДЛЯ МОНИТОРА, А ТО ХЕР ЕГО ЗНАЕТ, КАКИЕ ИВЕНТЫ ОНО ШЛЕТ
	if event == "monitor_touch" then side = 1 end
	if event == "mouse_click" or event == "monitor_touch" then

		if side == 1 then

			--ПЕРЕМЕННАЯ ВЫХОДА ИЗ ВСЕХ ЦИКЛОВ, ПАТАММУШТА ЛУА ГОВНО И НЕ ПОДДЕРЖИВАЕТ МНОЖЕСТВЕННЫЙ BREAK
			local exit1 = false

			--ХУЙНЮШЕЧКА ДЛЯ КЛИКА "НАЗАД"
			if #workPathHistory > 0 then
				if x==Obj["<"]["x1"] and y==Obj["<"]["y1"] and #workPathHistory > 0 then
						--ТЫК
						term.setBackgroundColor(colors.blue)
						term.setTextColor(colors.white)
						usualText(Obj["<"]["x1"],Obj["<"]["y1"],"<")
						sleep(0.2)
						--НЕ ТЫК
						workPath = workPathHistory[#workPathHistory]
						workPathHistory[#workPathHistory] = nil
						currentDesktop = 1
						displayApps(workPath,currentDesktop,currentBackground)
						exit1 = true
				end
			end

			--А ЭТО, КОРОЧ, ПЕРЕБОР ВСЕХ НИЖНИХ КНОПОЧЕК ДЛЯ ПЕРЕЛИСТЫВАНИЯ РАБОЧИХ СТОЛОВ
			for i=1,#ObjBottom do
				if exit1 then break end
				if x==ObjBottom[i]["x1"] and y==ObjBottom[i]["y1"] then
					currentDesktop = i
					displayApps(workPath,currentDesktop,currentBackground)
					exit1=true
				end
			end

			--А ЭТО ВООБЩЕ У-У-У-У-У
			--ЗАБЕЙ, КОРОЧ
			--ПРОСТО ЗАБЕЙ
			--В ОБЩЕМ
			--ЭТО ТАКАЯ ХУЙНЯ, КОТОРАЯ ПЕРЕБИРАЕТ МАССИВЧИК С ОБЪЕКТАМИ ПРИЛОЖЕНИЙ
			--КОРОЧ, ЗАБЫЛ УЖЕ, ЧТО ЭТО
			for key,val in pairs(ObjApp) do
				if exit1 then break end
				for i=appCounter,(appCounter+countOfAppsOnDesktop-1) do
					if exit1 then break end
					if ObjApp[key]["id"] == i then
						if x>=ObjApp[key]["x1"] and x<=ObjApp[key]["x2"] and y>=ObjApp[key]["y1"] and y<=ObjApp[key]["y2"] then
							square(ObjApp[key]["x1"],ObjApp[key]["y1"],appWidth,appHeight,colors.blue)
							drawKonkretnoApp(ObjApp[key]["x1"],ObjApp[key]["y1"],key,colors.blue,ObjApp[key]["id"])
							sleep(0.2)

							--ВАЖНО, СУКА!
							local fileFormat = ObjApp[key]["fileFormat"]

							if not fs.isDir(workPath.."/"..key) then

								if key ~= "OS" and key ~= "os" and fileFormat == nil then
									launchFile(workPath.."/"..key,fileFormat)

								elseif fileFormat == ".png" then
									launchFile(workPath.."/"..key,fileFormat)

								elseif fileFormat == ".zip" then
									windows.progressBar("auto","auto",20," ","Unarchiving",5)
									zip.unarchive(workPath.."/"..key,workPath)
								elseif fileFormat == ".cfg" then
									launchFile(workPath.."/"..key,fileFormat)

								elseif key == "OS" or key == "os" then
									windows.attention({"Can't open OS"},{"Cause it's already","running."})

								else
									windows.attention({"Can't open this"},{"Unknown file extension"})
								end

								exit1 = true
								displayApps(workPath,currentDesktop,currentBackground)
							else
								if fileFormat == ".app" then
									launchFile(workPath.."/"..key,fileFormat)
									displayApps(workPath,currentDesktop,currentBackground)
								else
									gotoDirectory(workPath.."/"..key)
									appCounter = 1
									displayApps(workPath,currentDesktop,currentBackground)
								end
								exit1 = true
							end
						end
					end
				end
			end

			if x>=Obj["OS"]["x1"] and x<=Obj["OS"]["x2"] and y>=Obj["OS"]["y1"] and y<=Obj["OS"]["y2"] then
				term.setBackgroundColor(colors.blue)
				term.setTextColor(colors.white)
				usualText(1,1," OS ")

				local contextAction = context.menu(Obj["OS"]["x1"]+1,Obj["OS"]["y1"]+1,{"About"},{"Update"},"-",{"Reboot"},{"Shutdown"},"-",{"Use Craft OS"},{"Made by ECS",true})
				if contextAction == "About" then
					launchFile("Applications/About")
					displayApps(workPath,currentDesktop,currentBackground)

				elseif contextAction == "Update" then
					pastebin("run","rjkm903f","cyka")
					fadeOut(0)
					os.reboot()

				elseif contextAction == "Reboot" then
					fadeOut(0)
					os.reboot()

				elseif contextAction == "Shutdown" then
					windows.tv(0)
					os.shutdown()

				elseif contextAction == "Use Craft OS" then
					exitFromProgram = true

				elseif contextAction == nil then
					displayApps(workPath,currentDesktop,currentBackground)
				end

			elseif x>=Obj["Search"]["x1"] and x<=Obj["Search"]["x2"] and y>=Obj["Search"]["y1"] and y<=Obj["Search"]["y2"] then
				term.setBackgroundColor(colors.blue)
				windows.colorText(xSize,1,"S",colors.white)
				local searchedPath = windows.search(xSize-27,2,28,2,"Search")
				if searchedPath ~= nil then
					if fs.isDir(searchedPath) then
						gotoDirectory(searchedPath)
						displayApps(workPath,currentDesktop,currentBackground)
					else
						launchFile(searchedPath,windows.getFileFormat(searchedPath))
					end
				end
				displayApps(workPath,currentDesktop,currentBackground)

			elseif x>=Obj["View"]["x1"] and x<=Obj["View"]["x2"] and y>=Obj["View"]["y1"] and y<=Obj["View"]["y2"] then
				
				term.setBackgroundColor(colors.blue)
				windows.colorText(Obj["View"]["x1"],Obj["View"]["y1"]," View ",colors.white)
				
				local s1 = "Show hidden files"; if showHiddenFiles then s1 = "Hide hidden files" end
				local s2 = "Show system files"; if showSystemFolders then s2 = "Hide system files" end
				local s3 = "Hide file format"; if hideFileFormat then s3 = "Show file format" end

				local contextAction = context.menu(Obj["View"]["x1"],Obj["OS"]["y1"]+1,{s1},{s2},"-",{s3})
				if contextAction == "Show hidden files" then
					showHiddenFiles = true
					config.write("System/OS/userdata.cfg","showHiddenFiles","true")
				elseif contextAction == "Hide hidden files" then
					showHiddenFiles = false
					config.write("System/OS/userdata.cfg","showHiddenFiles","false")
				elseif contextAction == "Show file format" then
					hideFileFormat = false
					config.write("System/OS/userdata.cfg","hideFileFormat","false")
				elseif contextAction == "Hide file format" then
					hideFileFormat = true
					config.write("System/OS/userdata.cfg","hideFileFormat","true")
				elseif contextAction == "Show system files" then
					showSystemFolders = true
					config.write("System/OS/userdata.cfg","showSystemFolders","true")
				elseif contextAction == "Hide system files" then
					showSystemFolders = false
					config.write("System/OS/userdata.cfg","showSystemFolders","false")
				end

				displayApps(workPath,currentDesktop,currentBackground)
			
			elseif Obj["closeNoti"] ~= nil and x==Obj["closeNoti"]["x1"] and y==Obj["closeNoti"]["y1"] then
				term.setBackgroundColor(colors.blue)
				windows.colorText(Obj["closeNoti"]["x1"],Obj["closeNoti"]["y1"],"x",colors.white)
				sleep(0.2)
				Notification = nil
				displayApps(workPath,currentDesktop,currentBackground)
			elseif x==xSize and y==ySize then
				Notification = {["type"]="Notification",["title"]="Message",["text"]="Cyka, mat tvoy ebal, pidor!"}
				displayApps(workPath,currentDesktop,currentBackground)
			end

		else
			local appSelected = false
			local exit1 = false
			for key,val in pairs(ObjApp) do
				if exit1 then break end
				for i=appCounter,(appCounter+countOfAppsOnDesktop-1) do
					if exit1 then break end
					if ObjApp[key]["id"] == i then
						if x>=ObjApp[key]["x1"] and x<=ObjApp[key]["x2"] and y>=ObjApp[key]["y1"] and y<=ObjApp[key]["y2"] then
							square(ObjApp[key]["x1"],ObjApp[key]["y1"],appWidth,appHeight,colors.blue)
							drawKonkretnoApp(ObjApp[key]["x1"],ObjApp[key]["y1"],key,colors.blue,ObjApp[key]["id"])
							
							local fileFormat = ObjApp[key]["fileFormat"]
							local thisIsDir = fs.isDir(workPath.."/"..key)
							local thisIsReadOnly = fs.isReadOnly(workPath.."/"..key)
							local thisIsArchive = false; if fileFormat == ".zip" then thisIsArchive = true end
							local contextAction = nil
							if fileFormat == ".png" then
								contextAction = context.menu(x,y,{"Set as wallpaper"},"-",{"Cut"},{"Copy"},{"Delete"},{"Rename"},"-",{"Upload to pastebin",thisIsDir},{"Add to archive"},"-",{"Properties"})
							elseif fileFormat == ".app" then
								contextAction = context.menu(x,y,{"Show content"},{"Run with arguments"},"-",{"Cut",thisIsReadOnly},{"Copy"},{"Delete",thisIsReadOnly},{"Rename",thisIsReadOnly},"-",{"Add to archive",thisIsArchive},"-",{"Properties"})
							else
								contextAction = context.menu(x,y,{"Edit",thisIsDir},{"Run with arguments",thisIsDir},"-",{"Cut",thisIsReadOnly},{"Copy"},{"Delete",thisIsReadOnly},{"Rename",thisIsReadOnly},"-",{"Upload to pastebin",thisIsDir},{"Add to archive",thisIsArchive},"-",{"Properties"})
							end

							if contextAction == "Edit" then
								exit = true
								fadeOut(0)
								prepareToExit()
								shell.run("edit "..workPath.."/"..key)
								fadeIn(0)

							elseif contextAction == "Cut" then
								cut(workPath.."/"..key)
								clipboardName = key

							elseif contextAction == "Copy" then
								copy(workPath.."/"..key)
								clipboardName = key

							elseif contextAction == "Delete" then
								fs.delete(workPath.."/"..key)								

							elseif contextAction == "Rename" then
								local fileFormat2 = windows.getFileFormat(key) or ""
								local data = windows.input("auto","auto","New name",15,{"Name",windows.hideFileFormat(key)},{"Format",fileFormat2})
								data[1] = windows.hideFileFormat(data[1])
								if data[1] == "" then data[1] = "MyProgram" end
								rename(workPath,key,data[1]..data[2])

							elseif contextAction == "Set as wallpaper" then
								setWallpaper(workPath.."/"..key)

							elseif contextAction == "Run with arguments" then
								local arguments = windows.input("auto","auto","Run",15,{"Arguments",""})
								exit = true
								launchFile(workPath.."/"..key,fileFormat,arguments[1])

							elseif contextAction == "Upload to pastebin" then
								launchFile("Pastebin.app",".app","upload "..workPath.."/"..key)
								--windows.progressBar("auto","auto",5," ","Uploading to pastebin",10)
								--pastebin("put","cyka",workPath.."/"..key)

							elseif contextAction == "Add to archive" then
								windows.progressBar("auto","auto",20," ","Archiving",10)
								zip.archive(workPath.."/"..key,workPath.."/"..key)

							elseif contextAction == "Properties" then
								displayApps(workPath,currentDesktop,currentBackground)
								windows.aboutFile(x,y,26,workPath.."/"..key)

							elseif contextAction == "Show content" then
								gotoDirectory(workPath.."/"..key)
							end

							exit1 = true
							appSelected = true
							displayApps(workPath,currentDesktop,currentBackground)
						end
					end
				end
			end

			if y>=2 and appSelected == false then

				local thisIsReadOnly = fs.isReadOnly(workPath)
				local isClipboardEmpty = true
				if clipboardName ~= nil then isClipboardEmpty = false end
				if isClipboardEmpty == false then isClipboardEmpty = thisIsReadOnly end

				local contextAction = context.menu(x,y,{"New file",thisIsReadOnly},{"New folder",thisIsReadOnly},{"Paste",isClipboardEmpty},"-",{"Run from pastebin"},{"Get from pastebin",thisIsReadOnly})

				if contextAction == "New file" then

					local filePath = windows.input("auto","auto","New file",15,{"Name",""})
					fadeOut(0)
					prepareToExit()
					shell.run("edit "..workPath.."/"..filePath[1])
					fadeIn(0)

				elseif contextAction == "New folder" then

					local filePath = windows.input("auto","auto","New folder",15,{"Name",""})
					fs.makeDir(workPath.."/"..filePath[1])
				
				elseif contextAction == "Paste" then

					if clipboardName ~= nil and fs.exists("System/Clipboard.temp") then
						paste(workPath,clipboardName)
					end

				elseif contextAction == "Run from pastebin" then
					local paste = windows.input("auto","auto","Run from pastebin",15,{"Paste name",""})
					pastebin("run",paste[1],"cyka")

				elseif contextAction == "Get from pastebin" then
					local paste = windows.input("auto","auto","Get from pastebin",15,{"Paste name",""},{"File name",""})
					pastebin("get",paste[1],paste[2])
				end

				displayApps(workPath,currentDesktop,currentBackground)
			end
		end
		--ОТРИСУЕМ ВЕРХНЮЮ ПАНЕЛЬКУ С ЧАСИКАМИ ПОСЛЕ НАЖАТИЯ НА ЭКРАН
		topBar(topBarColor)
		--НА ВСЯКИЙ ПОЖАРНЫЙ ВЫРУБАЕМ МИГАНИЕ КУРСОРА, А ТО БЫЛА УЖЕ ОДНА ХУЙНЯ
		term.setCursorBlink(false)

	--ПОДДЕРЖКА КОЛЕСА МЫШИ, ПРОКРУЧИВАЮЩЕГО РАБОЧИЕ СТОЛЫ
	elseif event == "mouse_scroll" then
		if side == -1 then
			currentDesktop = currentDesktop + 1
			if currentDesktop > countOfDesktops then
				currentDesktop = countOfDesktops
			else
				displayApps(workPath,currentDesktop,currentBackground)
			end
		elseif side == 1 then
			currentDesktop = currentDesktop - 1
			if currentDesktop < 1 then
				currentDesktop = 1
			else
				displayApps(workPath,currentDesktop,currentBackground)
			end
		end
	elseif event == "disk" then
		displayApps(workPath,currentDesktop,currentBackground)
	elseif event == "disk_eject" then
		currentDesktop = 1
		workPath = ""
		workPathHistory = {}
		displayApps(workPath,currentDesktop,currentBackground)
	--[[elseif event == "rednet_message" then
		local msg = textutils.unserialize(x)
		if msg ~= nil then
			if msg["type"] ~= nil and msg["type"] == "Notification" then
				Notification = msg
				displayApps(workPath,currentDesktop,currentBackground)
			end
		end]]
	end
end

fadeOut(0)
prepareToExit()
--windows.tv(0)