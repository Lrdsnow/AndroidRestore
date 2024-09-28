//
//  GooglePlay.swift
//  AndroidRestore
//
//  Created by Lrdsnow on 9/26/24.
//

import SwiftUI

func checkAppAvailability(bundleId: String, appName: String, completion: @escaping (String, String?, Bool) -> Void) {
    if let id = randomAppBundleIDs[bundleId] {
        completion("found", nil, true)
        return
    }
    
    // Construct the initial URL with the inputted bundle ID
    guard let initialURL = URL(string: "https://play.google.com/store/apps/details?id=\(bundleId)") else {
        completion("notfound", nil, false)
        return
    }

    // Create a URL request for a HEAD request
    var request = URLRequest(url: initialURL)
    request.httpMethod = "HEAD"

    // Send the initial request
    let task = URLSession.shared.dataTask(with: request) { _, response, error in
        // Check for errors
        if let error = error {
            print("Error: \(error.localizedDescription)")
            completion("notfound", nil, false)
            return
        }

        // Check the response status code
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200:
                completion("found", nil, true)  // App is found
            default:
                // If status is anything other than 404, search for the app name
                searchForApp(name: appName, bundleID: bundleId) { result, foundBundleId, confident in
                    completion(result, foundBundleId, confident)
                }
            }
        } else {
            completion("notfound", nil, false)
        }
    }

    task.resume()
}

func searchForApp(name: String, bundleID: String, completion: @escaping (String, String?, Bool) -> Void) {
    // Construct the search URL
    guard let searchURL = URL(string: "https://play.google.com/store/search?q=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)") else {
        completion("notfound", nil, false)
        return
    }

    // Send a GET request to search for the app
    let task = URLSession.shared.dataTask(with: searchURL) { data, response, error in
        if let error = error {
            print("Error: \(error.localizedDescription)")
            completion("notfound", nil, false)
            return
        }

        guard let data = data else {
            completion("notfound", nil, false)
            return
        }

        // Parse the HTML response to find the first occurrence of the app's URL
        if let htmlString = String(data: data, encoding: .utf8) {
            // Use a regular expression to find the first occurrence of /store/apps/details?id=<bundle_id>
            let pattern = "/store/apps/details\\?id=([\\w\\d.]+)"
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let matches = regex?.matches(in: htmlString, options: [], range: NSRange(location: 0, length: htmlString.utf16.count))
            
            if let match = matches?.first, let range = Range(match.range(at: 1), in: htmlString) {
                let foundBundleId = String(htmlString[range])
                let confident = foundBundleId.contains(bundleID)
                completion("unsure", foundBundleId, confident)  // App found but unsure if it's the correct one
                return
            }
        }

        completion("notfound", nil, false)  // App not found
    }

    task.resume()
}

var randomAppBundleIDs: [String: String] = [
    "com.amazon.Amazon": "com.amazon.mShop.android.shopping",
    "com.facebook.Facebook": "com.facebook.katana",
    "com.twitter.twitter": "com.twitter.android",
    "com.instagram": "com.instagram.android",
    "com.spotify.client": "com.spotify.music",
    "com.google.Maps": "com.google.android.apps.maps",
    "com.netflix.Netflix": "com.netflix.mediaclient",
    "com.snapchat.Snapchat": "com.snapchat.android",
    "com.youtube": "com.google.android.youtube",
    "org.telegram.telegram": "org.telegram.messenger",
    "com.slack.Slack": "com.Slack",
    "com.adobe.Adobe-Reader": "com.adobe.reader",
    "pinterest": "com.pinterest.android",
    "com.linkedin.LinkedIn": "com.linkedin.android",
    "com.ebay.iphone": "com.ebay.mobile",
    "com.spotify.Remote": "com.spotify.music",
    "com.dropbox.Dropbox": "com.getdropbox.android",
    "com.soundcloud.SoundCloud": "com.soundcloud.android",
    "com.pandora": "com.pandora.android",
    "com.yelp.yelp": "com.yelp.android",
    "com.foursquare.Foursquare": "com.foursquare.foursquareapp",
    "com.canva.canvaeditor":"com.canva.editor",
    "com.github.stormbreaker.prod":"com.github.android",
    "com.google.GoogleMobile":"com.google.android.googlequicksearchbox",
    "com.shazam.Shazam":"com.shazam.android",
    "org.ppsspp.ppsspp-free":"org.ppsspp.ppsspp",
    "com.google.GVDialer":"com.google.android.apps.googlevoice",
    "com.dcdwebdesign.saturn":"com.joinsaturn.android1",
    "com.microsoft.Office.Outlook":"com.microsoft.office.outlook",
    "net.techet.netanalyzerlite":"net.techet.netanalyzerlite.an",
    "com.asus.asusrouter":"com.asus.aihome",
    "com.authy":"com.authy.authy",
    "ch.protonmail.vpn":"ch.protonvpn.android",
    "com.openai.chat":"com.openai.chatgpt",
    "com.google.Drive":"com.google.android.apps.docs",
    "com.google.Gmail":"com.google.android.gm",
    "com.amazon.aiv.AIVApp":"com.amazon.avod.thirdpartyclient",
    "com.google.Docs":"com.google.android.apps.docs.editors.docs",
    "com.google.youtube":"com.google.android.youtube",
    "com.atebits.Tweetie2":"com.twitter.android",
    "com.utmapp.UTM-SE":"com.google.android.apps.maps",
    "com.cloudflare.1dot1dot1dot1":"com.cloudflare.onedotonedotonedotone",
    "com.crystalnix.ServerAuditor":"com.server.auditor.ssh.client",
    "com.supercell.soil":"com.supercell.hayday",
    "com.burbn.instagram":"com.instagram.android",
    "com.nanoleaf.nanoleaf":"me.nanoleaf.nanoleaf",
    "com.wireguard":"com.wireguard.android",
    "com.amazon.echo":"com.amazon.dee.app",
    "com.google.photos":"com.google.android.apps.photos",
    "com.edupoint.StudentVUE":"com.FreeLance.StudentVUE",
    "com.toyopagroup.picaboo":"com.snapchat.android",
    "com.reddit.Reddit":"com.reddit.frontpage",
    "com.valvesoftware.Steam":"com.valvesoftware.android.steam.community",
    "com.google.youtubemusic":"com.google.android.apps.youtube.music",
]
