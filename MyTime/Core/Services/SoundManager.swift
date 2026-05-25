//
//  SoundManager.swift
//  MyTime
//
//  Created by Welton Felix on 25/05/26.
//

import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    private var player: AVAudioPlayer?

    func playChime() {
        guard
            let url = Bundle.main.url(
                forResource: "chime",
                withExtension: "mp3"
            )
        else {
            print("Could not load sound resource")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default
            )
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.play()

        } catch {
            print("Error playing sound\(error.localizedDescription)")
        }
    }
}
