import SwiftUI

struct StatusBar: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
