// EN PRODUCTION (derrière Nginx sur AWS), le frontend et l'API sont servis
// depuis le même domaine, donc on utilise un chemin relatif : '/api'.
// EN LOCAL (test sur ta machine), le frontend (port 5500) et le backend
// (port 3000) sont sur des ports différents, donc on doit préciser l'URL
// complète. Change cette ligne selon le contexte, ou remets '/api' avant
// de pousser sur GitHub / déployer.
const API_BASE = 'http://localhost:3000/api';
// const API_BASE = '/api'; // <- à utiliser une fois derrière Nginx

const form = document.getElementById('todo-form');
const input = document.getElementById('todo-input');
const list = document.getElementById('todo-list');
const emptyState = document.getElementById('empty-state');

function renderTodos(todos) {
  list.innerHTML = '';
  emptyState.classList.toggle('visible', todos.length === 0);

  todos.forEach((todo) => {
    const li = document.createElement('li');
    li.dataset.id = todo.id;

    // --- Mode "affichage normal" ---
    const title = document.createElement('span');
    title.className = 'todo-title';
    title.textContent = todo.title;

    const editBtn = document.createElement('button');
    editBtn.className = 'btn-edit';
    editBtn.textContent = 'Modifier';
    editBtn.setAttribute('aria-label', `Modifier la tâche "${todo.title}"`);

    const delBtn = document.createElement('button');
    delBtn.className = 'btn-delete';
    delBtn.textContent = 'Supprimer';
    delBtn.setAttribute('aria-label', `Supprimer la tâche "${todo.title}"`);
    delBtn.onclick = async () => {
      await fetch(`${API_BASE}/todos/${todo.id}`, { method: 'DELETE' });
      loadTodos();
    };

    // --- Mode "édition" : remplace l'affichage par un champ + Enregistrer/Annuler ---
    editBtn.onclick = () => {
      li.innerHTML = '';

      const editInput = document.createElement('input');
      editInput.type = 'text';
      editInput.className = 'edit-input';
      editInput.value = todo.title;

      const saveBtn = document.createElement('button');
      saveBtn.className = 'btn-save';
      saveBtn.textContent = 'Enregistrer';
      saveBtn.onclick = async () => {
        const newTitle = editInput.value.trim();
        if (!newTitle) return;
        await fetch(`${API_BASE}/todos/${todo.id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ title: newTitle }),
        });
        loadTodos();
      };

      const cancelBtn = document.createElement('button');
      cancelBtn.className = 'btn-cancel';
      cancelBtn.textContent = 'Annuler';
      cancelBtn.onclick = () => loadTodos();

      li.appendChild(editInput);
      li.appendChild(saveBtn);
      li.appendChild(cancelBtn);
      editInput.focus();
    };

    li.appendChild(title);
    li.appendChild(editBtn);
    li.appendChild(delBtn);
    list.appendChild(li);
  });
}

async function loadTodos() {
  const res = await fetch(`${API_BASE}/todos`);
  const todos = await res.json();
  renderTodos(todos);
}

form.addEventListener('submit', async (e) => {
  e.preventDefault();
  const title = input.value.trim();
  if (!title) return;

  await fetch(`${API_BASE}/todos`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title }),
  });
  input.value = '';
  input.focus();
  loadTodos();
});

loadTodos();