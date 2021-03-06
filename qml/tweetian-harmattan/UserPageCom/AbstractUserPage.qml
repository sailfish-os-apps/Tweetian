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
import "../Component"

Page {
    id: root
    allowedOrientations: Orientation.All
    property string headerText
    property int headerNumber: 0
    property string emptyText
    property alias delegate: listView.delegate
    property string reloadType: "all"

    property bool backButtonEnabled: true
    property bool loadMoreButtonVisible: true

    property variant user
    property ListView listView: listView

    signal reload

    onStatusChanged: if (status === PageStatus.Deactivating) loadingRect.visible = false
    Component.onCompleted: reload()

    PullDownListView {
        id: listView
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left; right: parent.right }
        model: ListModel {}
        header: PageHeader {
            title: "@" + user.screenName + "\n" + root.headerText
        }

        footer: LoadMoreButton {
            visible: loadMoreButtonVisible
            enabled: !loadingRect.visible
            onClicked: {
                reloadType = "older"
                reload()
            }
        }
    }

    VerticalScrollDecorator { flickable: listView }

    Text {
        anchors.centerIn: parent
        visible: listView.count == 0 && !loadingRect.visible
        font.pixelSize: constant.fontSizeXXLarge
        color: constant.colorMid
        text: root.emptyText
    }
}
