function init()
  local noteText = config.getParameter("noteText", "")
  noteText = noteText:gsub("%^[#%a%x]+;", "")
  widget.setText("lblNoteText", noteText)
end
