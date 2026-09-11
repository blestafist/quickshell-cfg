import QtQuick

Item {
    property bool opened: false
    property bool available: false
    property bool connected: false
    property bool busy: false
    property bool loadingLocations: false
    property string server: ""
    property string location: ""
    property string protocol: ""
    property int load: -1
    property string error: ""
    property string message: ""
    property var countries: []
    property var cities: []
    property var settings: ({})

    signal actionCompleted(bool success)

    function refresh() {}
    function loadCountries() {}
    function loadCities(country) {}
    function connectTarget(target) {}
    function disconnect() {}
    function setSetting(name, value) {}
}
