/*
    Copyright (C) 2012 Dickson Leong
    This file is part of Tweetian.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

import QtQuick 1.1
import com.nokia.symbian 1.1
import "../Component"
import "../Delegate"
import "../storage.js" as Database
import "../Services/Twitter.js" as Twitter

Item{
    id: root
    implicitHeight: mainView.height
    implicitWidth: mainView.width

    property string reloadType: "all"
    property ListModel fullModel: ListModel{}
    property WorkerScript parser: directMsgParser

    property bool busy: true
    property int unreadCount: 0

    signal dataParsed(string type, int count, bool createNotification)

    onDataParsed: {
        if(type == "insert") {
            if(createNotification) {
                unreadCount += count
                if(symbian.foreground && mainPage.status !== PageStatus.Active)
                    infoBanner.alert(qsTr("%n new message(s)", "", unreadCount))
            }
            busy = false
        }
        else if(type == "clearAndInsert") {
            busy = false
        }
        else if(type == "database") {
            if(fullModel.count > 0) {
                directMsgView.lastUpdate = settings.directMsgLastUpdate
                refresh("newer")
            }
            else{
                refresh("all")
            }
        }
    }

    function initialize(){
        var directMsg = Database.getDM()
        parser.insertFromDatabase(directMsg)
        busy = true
    }

    function positionAtTop(){
        directMsgView.positionViewAtBeginning()
    }

    function refresh(type){
        var sinceId = ""
        if(directMsgView.count > 0){
            if(type === "newer") sinceId = fullModel.get(0).tweetId
            else if(type === "all") directMsgView.model.clear()
        }
        else type = "all"
        reloadType = type
        Twitter.getDirectMsg(sinceId, "", internal.successCallback, internal.failureCallback)
        busy = true
    }

    AbstractListView{
        id: directMsgView
        anchors.fill: parent
        header: settings.enableStreaming ? streamingHeader : pullToRefreshHeader
        delegate: DMThreadDelegate{}
        model: ListModel{}
        onPullDownRefresh: if(userStream.status === 0) refresh("newer")

        Component{ id: pullToRefreshHeader; PullToRefreshHeader{} }
        Component{ id: streamingHeader; StreamingHeader{} }
    }

    Text{
        anchors.centerIn: parent
        font.pixelSize: constant.fontSizeXXLarge
        color: constant.colorMid
        text: qsTr("No message")
        visible: directMsgView.count == 0 && !busy
    }

    ScrollDecorator { platformInverted: settings.invertedTheme; flickableItem: directMsgView }

    Timer{
        id: refreshTimeStampTimer
        interval: 60000
        repeat: true
        running: symbian.foreground
        triggeredOnStart: true
        onTriggered: if(directMsgView.count > 0) parser.refreshTime()
    }

    Timer{
        id: autoRefreshTimer
        interval: settings.directMsgRefreshFreq * 60 * 1000
        repeat: true
        running: networkMonitor.online && !settings.enableStreaming
        onTriggered: refresh("newer")
    }

    WorkerScript{
        id: directMsgParser
        source: "../WorkerScript/DirectMsgParser.js"
        onMessage: dataParsed(messageObject.type, messageObject.count, messageObject.createNotification)

        function insert(recieveMsg, sentMsg){
            var msg = {
                type: "insert",
                model: fullModel,
                threadModel: directMsgView.model,
                recieveMsg: recieveMsg,
                sentMsg: sentMsg
            }
            sendMessage(msg)
            directMsgView.lastUpdate = new Date().toString()
        }

        function clearAndInsert(receiveMsg, sentMsg){
            var msg = {
                type: "clearAndInsert",
                model: fullModel,
                threadModel: directMsgView.model,
                recieveMsg: receiveMsg,
                sentMsg: sentMsg
            }
            sendMessage(msg)
        }

        function refreshTime(){
            sendMessage({type: "time", threadModel: directMsgView.model})
        }

        function insertFromDatabase(data){
            var msg = {
                type: "database",
                model: fullModel,
                threadModel: directMsgView.model,
                data: data
            }
            sendMessage(msg)
        }

        function remove(id){
            sendMessage({type: "delete", model: fullModel, id: id})
        }

        function setProperty(index, propertyString, value){
            var msg = {
                type: "setProperty",
                threadModel: directMsgView.model,
                index: index,
                property: propertyString,
                value: value
            }
            sendMessage(msg)
        }
    }

    QtObject{
        id: internal

        function successCallback(dmRecieve, dmSent){
            if(reloadType == "all") parser.clearAndInsert(dmRecieve, dmSent)
            else if(reloadType == "newer") parser.insert(dmRecieve, dmSent)
            if(autoRefreshTimer.running) autoRefreshTimer.restart()
        }

        function failureCallback(status, statusText){
            infoBanner.showHttpError(status, statusText)
            busy = false
        }
    }

    Component.onDestruction: {
        Database.setSetting([["directMsgLastUpdate", directMsgView.lastUpdate]])
        var directMsgs = []
        for(var i=0; i<Math.min(100, fullModel.count); i++){
            var directMsgObj = {
                "tweetId": fullModel.get(i).tweetId,
                "userName": fullModel.get(i).userName,
                "screenName": fullModel.get(i).screenName,
                "tweetText": fullModel.get(i).tweetText,
                "profileImageUrl": fullModel.get(i).profileImageUrl,
                "createdAt": fullModel.get(i).createdAt,
                "sentMsg": fullModel.get(i).sentMsg ? 1 : 0
            }
            directMsgs.push(directMsgObj)
        }
        Database.storeDM(directMsgs)
    }
}
