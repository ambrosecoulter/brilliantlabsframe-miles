import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_controller.dart';
import 'dart:async';

class NoteDetailPage extends StatefulWidget {
  final Note note;

  const NoteDetailPage({Key? key, required this.note}) : super(key: key);

  @override
  _NoteDetailPageState createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, appController, child) {
        // Update the content controller if the note content has changed
        if (_contentController.text != widget.note.content) {
          _contentController.text = widget.note.content;
        }

        return WillPopScope(
          onWillPop: () async {
            if (appController.isTranscribing) {
              await appController.stopTranscription();
              // Update the note content after stopping transcription
              widget.note.title = _titleController.text;
              widget.note.content = _contentController.text;
              await appController.updateNote(widget.note);
            }
            return true;
          },
          child: Scaffold(
            backgroundColor: Color.fromRGBO(35, 35, 35, 1),
            appBar: AppBar(
              title: Text('Edit Note', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _showDeleteConfirmation(context, appController),
                ),
              ],
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  color: Color.fromRGBO(35, 35, 35, 1),
                ),
              ),
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () async {
                  if (appController.isTranscribing) {
                    await appController.stopTranscription();
                    // Update the note content after stopping transcription
                    widget.note.title = _titleController.text;
                    widget.note.content = _contentController.text;
                    await appController.updateNote(widget.note);
                  }
                  Navigator.of(context).pop();
                },
              ),
            ),
            body: Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Expanded(child: _buildNoteEditor(appController, context)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoteEditor(AppController appController, BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Color.fromRGBO(42, 42, 42, 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextFormField(
              controller: _titleController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Note Title',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Color.fromRGBO(42, 42, 42, 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: appController.isTranscribing
                  ? SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          widget.note.content,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  : TextFormField(
                      controller: _contentController,
                      style: TextStyle(color: Colors.white),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                        hintText: 'Enter your note here...',
                        hintStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
            ),
          ),
          SizedBox(height: 16),
          appController.isFrameConnected
              ? Row(
                  children: [
                    Expanded(
                      child: _buildSaveButton(appController),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildTranscribeButton(appController),
                    ),
                  ],
                )
              : _buildSaveButton(appController),
        ],
      ),
    );
  }

  Widget _buildSaveButton(AppController appController) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          if (appController.isTranscribing) {
            await appController.stopTranscription();
          }
          widget.note.title = _titleController.text;
          widget.note.content = _contentController.text;
          appController.updateNote(widget.note);
          _showSavedNotification(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Color.fromRGBO(247, 252, 170, 1),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          padding: EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text('Save Note'),
      ),
    );
  }

  Widget _buildTranscribeButton(AppController appController) {
    return ElevatedButton(
      onPressed: appController.isTranscribing
          ? appController.stopTranscription
          : () {
              _contentController.text = widget.note.content;
              appController.startTranscription(widget.note);
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: Color.fromRGBO(42, 42, 42, 1),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
        padding: EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(appController.isTranscribing ? 'Stop' : 'Transcribe'),
    );
  }

  void _showSavedNotification(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Note saved successfully'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AppController appController) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color.fromRGBO(35, 35, 35, 1),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20), // Changed from 16 to 20
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to delete this note?',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (appController.isTranscribing) {
                        await appController.stopTranscription();
                      }
                      appController.deleteNote(widget.note);
                      Navigator.pop(context); // Close the modal
                      Navigator.pop(context); // Go back to all notes
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
