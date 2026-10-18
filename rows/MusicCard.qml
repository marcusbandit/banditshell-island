import QtQuick

// Now playing, opened: cover, title, where the song is, the line being sung
// and the one after it, and the transport.
Item {
    id: root

    property var theme
    property var music
    property var lyrics

    implicitHeight: content.implicitHeight

    Column {
        id: content

        width: parent.width
        spacing: 10

        Item {
            width: parent.width
            height: 48

            Art {
                id: art

                theme: root.theme
                width: 48
                height: 48
                source: root.music?.art ?? ""
                glyph: (root.music?.title ?? "?").slice(0, 1).toUpperCase()
                radius: 10
            }

            Column {
                anchors.left: art.right
                anchors.leftMargin: 12
                anchors.right: transport.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Line {
                    theme: root.theme
                    width: parent.width
                    text: root.music?.title ?? ""
                    font.pixelSize: root.theme.large
                    font.weight: Font.DemiBold
                }

                Line {
                    theme: root.theme
                    width: parent.width
                    text: [root.music?.artist, root.music?.album].filter(s => s).join("  ")
                    color: root.theme.dim
                }
            }

            Row {
                id: transport

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: [
                        {
                            glyph: "⏮",
                            act: "previous"
                        },
                        {
                            glyph: root.music?.playing ? "⏸" : "▶",
                            act: "toggle"
                        },
                        {
                            glyph: "⏭",
                            act: "next"
                        }
                    ]

                    Rectangle {
                        required property var modelData

                        width: 28
                        height: 28
                        radius: 14
                        color: press.containsMouse ? root.theme.hover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.glyph
                            color: root.theme.text
                            font.pixelSize: root.theme.normal
                        }

                        MouseArea {
                            id: press

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const p = root.music?.player;
                                if (!p)
                                    return;
                                if (parent.modelData.act === "toggle")
                                    p.togglePlaying();
                                else if (parent.modelData.act === "next")
                                    p.next();
                                else
                                    p.previous();
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 14

            Line {
                id: at

                theme: root.theme
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.clock(root.music?.position ?? 0)
                color: root.theme.dim
                font.pixelSize: root.theme.small
                font.features: {
                    "tnum": 1
                }
            }

            Rectangle {
                id: track

                anchors.left: at.right
                anchors.right: total.left
                anchors.margins: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 3
                radius: 1.5
                color: root.theme.track

                Rectangle {
                    width: parent.width * Math.min(1, (root.music?.length ?? 0) > 0 ? root.music.position / root.music.length : 0)
                    height: parent.height
                    radius: parent.radius
                    color: root.theme.text
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => root.music?.seekTo((e.x - 6) / track.width * (root.music?.length ?? 0))
                }
            }

            Line {
                id: total

                theme: root.theme
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.clock(root.music?.length ?? 0)
                color: root.theme.dim
                font.pixelSize: root.theme.small
                font.features: {
                    "tnum": 1
                }
            }
        }

        Column {
            width: parent.width
            spacing: 6
            visible: (root.lyrics?.lines?.length ?? 0) > 0

            LyricLine {
                theme: root.theme
                width: parent.width
                line: root.lyrics?.current?.gap ? null : root.lyrics?.current
                fillOf: w => root.lyrics.fill(w)
                size: root.theme.huge
            }

            LyricLine {
                theme: root.theme
                width: parent.width
                line: root.lyrics?.next
                live: false
                size: root.theme.normal
            }

            Line {
                theme: root.theme
                text: root.lyrics?.source ? `lyrics from ${root.lyrics.source}` : ""
                color: Qt.alpha(root.theme.dim, 0.7)
                font.pixelSize: root.theme.small
            }
        }
    }

    function clock(s: real): string {
        const t = Math.max(0, Math.floor(s));
        return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, "0")}`;
    }
}
