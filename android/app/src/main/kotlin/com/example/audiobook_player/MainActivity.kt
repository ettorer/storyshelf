package com.example.audiobook_player

import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "storyshelf/audio_folder"
        ).setMethodCallHandler { call, result ->
            if (call.method != "copyMp3Files") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val treeUri = call.argument<String>("treeUri")
            if (treeUri.isNullOrBlank()) {
                result.error("INVALID_FOLDER", "The selected folder URI is missing.", null)
                return@setMethodCallHandler
            }

            try {
                result.success(copyMp3Files(Uri.parse(treeUri)))
            } catch (error: Exception) {
                result.error("FOLDER_READ_FAILED", error.message, null)
            }
        }
    }

    /**
     * Copies the MP3s of the picked folder into the cache and returns their
     * paths. The epub-to-audio extras next to them (NN - Title.json sidecars
     * and the images/ subfolder) are copied into the same temporary folder so
     * the Dart side can import them too.
     */
    private fun copyMp3Files(treeUri: Uri): List<String> {
        val rootDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
        val destination = File(cacheDir, "storyshelf-chapters/${UUID.randomUUID()}")
        if (!destination.mkdirs() && !destination.isDirectory) {
            throw IllegalStateException("Could not prepare temporary chapter files.")
        }
        val copied = mutableListOf<String>()
        for (child in listChildren(treeUri, rootDocumentId)) {
            when {
                child.isDirectory && child.name.equals("images", ignoreCase = true) -> {
                    val imageFolder = File(destination, "images")
                    imageFolder.mkdirs()
                    for (image in listChildren(treeUri, child.documentId)) {
                        if (image.isDirectory || !IMAGE_NAME.matches(image.name)) continue
                        try {
                            copyDocument(treeUri, image, imageFolder)
                        } catch (_: Exception) {
                            // A missing or unreadable image is skipped.
                        }
                    }
                }
                child.isDirectory -> Unit
                child.name.endsWith(".mp3", ignoreCase = true) ->
                    copied.add(copyDocument(treeUri, child, destination).absolutePath)
                child.name.endsWith(".json", ignoreCase = true) -> try {
                    copyDocument(treeUri, child, destination)
                } catch (_: Exception) {
                    // Sidecars are optional.
                }
            }
        }
        return copied
    }

    private data class Child(val documentId: String, val name: String, val isDirectory: Boolean)

    private fun listChildren(treeUri: Uri, parentDocumentId: String): List<Child> {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            parentDocumentId
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE
        )
        val cursor = contentResolver.query(childrenUri, projection, null, null, null)
            ?: throw IllegalStateException("Could not read the selected folder.")
        val result = mutableListOf<Child>()
        cursor.use {
            val idColumn = it.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = it.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeColumn = it.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
            while (it.moveToNext()) {
                val id = it.getString(idColumn) ?: continue
                val name = it.getString(nameColumn) ?: continue
                val isDirectory =
                    it.getString(mimeColumn) == DocumentsContract.Document.MIME_TYPE_DIR
                result.add(Child(id, name, isDirectory))
            }
        }
        return result
    }

    private fun copyDocument(treeUri: Uri, child: Child, folder: File): File {
        val documentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, child.documentId)
        val output = File(folder, child.name.replace(Regex("[/\\\\]"), "_"))
        val inputStream = contentResolver.openInputStream(documentUri)
            ?: throw IllegalStateException("Could not read ${child.name}.")
        inputStream.use { input ->
            output.outputStream().use { fileOutput -> input.copyTo(fileOutput) }
        }
        return output
    }

    companion object {
        private val IMAGE_NAME = Regex(".*\\.(jpe?g|png|gif|webp|bmp)$", RegexOption.IGNORE_CASE)
    }
}
