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

import QtQuick 2.1
import Sailfish.Silica 1.0
import QtPositioning 5.0
import "Services/Twitter.js" as Twitter
import "Utils/Calculations.js" as Calculate
import "Component"
import "Delegate"

Page {
    id: nearbyTweetsPage

    property double latitude
    property double longitude

    allowedOrientations: Orientation.All
    Component.onCompleted: positionSource.start()

   /* tools: ToolBarLayout {
        ToolIcon {
            id: backButton
            platformIconId: "toolbar-back" + (enabled ? "" : "-dimmed")
            onClicked: pageStack.pop()
        }
        ToolIcon {
            platformIconId: "toolbar-view-menu"
            onClicked: menu.open()
        }
    }

    Menu {
        id: menu

        MenuLayout {
            MenuItem {
                text: qsTr("Refresh Cache & Location")
                enabled: !header.busy
                onClicked: positionSource.start()
            }
        }
    } */

    PullDownListView {
        id: searchListView
        property bool stayAtCurrentPosition: internal.reloadType === "newer"
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        enabled: !header.busy || count > 0
        footer: LoadMoreButton {
            visible: searchListView.count > 0
            enabled: !header.busy
            onClicked: internal.refresh("older")
        }
        delegate: TweetDelegate {}
        model: ListModel {}
    }

    Text {
        anchors.centerIn: parent
        font.pixelSize: constant.fontSizeXXLarge
        color: constant.colorMid
        text: qsTr("No tweets")
        visible: searchListView.count == 0 // && !header.busy
    }

   // VerticalScrollDecorator { flickableItem: searchListView }

    PageHeader {
        id: header
        title: positionSource.active ? qsTr("Getting location...") : qsTr("Nearby Tweets")
    }

    WorkerScript {
        id: searchParser
        source: "WorkerScript/SearchParser.js"
        onMessage: {
       /*     backButton.enabled = true
            if (internal.reloadType === "newer") {
                header.countBubbleVisible = true
                header.countBubbleValue = messageObject.count
            }
            else {
                header.countBubbleVisible = false
                header.countBubbleValue = 0
            }*/
            //header.busy = false
        }
    }

    PositionSource {
        id: positionSource
        updateInterval: 1000

        onPositionChanged: {
            nearbyTweetsPage.latitude = position.coordinate.latitude
            nearbyTweetsPage.longitude = position.coordinate.longitude
            stop()
            internal.refresh("all")
        }
    }

    QtObject {
        id: internal

        property string reloadType: "all"

        function refresh(type) {
            if (searchListView.count <= 0)
                type = "all";
            var sinceId = "", maxId = "";
            switch (type) {
            case "newer": sinceId = searchListView.model.get(0).id; break;
            case "older": maxId =  searchListView.model.get(searchListView.count - 1).id; break;
            case "all": searchListView.model.clear(); break;
            default: throw new Error("Invalid type");
            }
            internal.reloadType = type
            Twitter.getNearbyTweets(latitude, longitude, sinceId, Calculate.minusOne(maxId), onSuccess, onFailure)
            //header.busy = true
        }

        function onSuccess(data) {
            if (reloadType != "older") searchListView.lastUpdate = new Date().toString()
        //    backButton.enabled = false
            searchParser.sendMessage({ type: reloadType, model: searchListView.model, data: data})
        }

        function onFailure(status, statusText) {
            infoBanner.showHttpError(status, statusText)
            header.busy = false
        }
    }
}
