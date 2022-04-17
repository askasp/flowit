defmodule FlowitWeb.CanvasLive do
  alias Flowit.FileInterface
  @height_unit 100
  @width_unit 120
  # If you generated an app with mix phx.new --live,
  # the line below would be: use MyAppWeb, :live_view
  use FlowitWeb, :live_view

  def mount(_params, %{}, socket) do
    res = Agent.start(fn -> %{} end, name: :flow_reg)
    flows = Agent.get(:flow_reg, fn x -> x end)

    {:ok,
     assign(socket,
       myheight: @height_unit,
       flow: nil,
       flow_name_suggestion: "myflow",
       flows: flows
     )}
  end

  @impl true
  def handle_params(%{"flow" => flow}, _uri, socket) do
    # flow = flow_file
    {:noreply, assign(socket, flow: socket.assigns.flows[flow])}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  def handle_event("set_flow", %{"flow" => flow}, socket) do
    {:noreply, push_patch(socket, to: "/flows/#{flow}")}
  end

  def handle_event("create_flow", %{"flowname" => flowname}, socket) do
    # This is sent when  I press close on set flow modal, It should not.. but this works for now
    if flowname == "" do
      {:noreply, socket}
    else
      case Map.get(socket.assigns.flows, flowname) do
        nil ->
          flows =
            Map.put(socket.assigns.flows, flowname, %{"name" => flowname, "components" => []})

          Agent.update(:flow_reg, fn x -> flows end)
          {:noreply, assign(socket, flows: flows)}

        _x ->
          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("add_view", %{"name" => name, "dispatched_by_id" => dispatched_by_id}, socket) do

    dispatched_by_component = Enum.find(socket.assigns.flow["components"], fn component -> dispatched_by_id == component["gui_id"] end)
    |> fn comp -> %{"name" => comp["name"], "type" => comp["type"]} end.()

    component = [
      %{
        "type" => "view",
        "name" => name,
        "dispatched_by_id" => dispatched_by_id,
        "dispatched_by_component" => [dispatched_by_component],
        "gui_id" => UUID.uuid1()
      }
    ]

    update_flow(component, socket)
  end

  defp update_flow(component, socket) do
    components = socket.assigns.flow["components"] ++ component
    flow = Map.put(socket.assigns.flow, "components", components)
    flows = Map.put(socket.assigns.flows, flow["name"], flow)
    Agent.update(:flow_reg, fn _x -> flows end)
    {:noreply, assign(socket, flows: flows, flow: flow)}
  end

  @impl true
  def handle_event(
        "add_command",
        %{
          "command" => command,
          "command_params" => command_params,
          "dispatched_by_id" => dispatched_by_id
        },
        socket
      ) do

    dispatched_by_component = Enum.find(socket.assigns.flow["components"], fn component -> dispatched_by_id == component["gui_id"] end)
    |> fn comp -> %{"name" => comp["name"], "type" => comp["type"]} end.()

    component = [
      %{
        "type" => "command",
        "name" => command,
        "dispatched_by_id" => dispatched_by_id,
        "dispatched_by_component" => [dispatched_by_component],
        "command_params" => command_params,
        "gui_id" => UUID.uuid1()
      }
    ]

    update_flow(component, socket)
  end

  @impl true
  def handle_event(
        "add_event",
        %{
          "event" => event,
          "event_params" => event_params,
          "aggregate" => aggregate,
          "dispatched_by_id" => dispatched_by_id
        },
        socket
      ) do

    dispatched_by_component = Enum.find(socket.assigns.flow["components"], fn component -> dispatched_by_id == component["gui_id"] end)
    |> fn comp -> %{"name" => comp["name"], "type" => comp["type"]} end.()

    component = [
      %{
        "type" => "event",
        "name" => event,
        "dispatched_by_id" => dispatched_by_id,
        "dispatched_by_component" => [dispatched_by_component],
        "event_params" => event_params,
        "gui_id" => UUID.uuid1(),
        "aggregate" => aggregate,
      }
    ]

    update_flow(component, socket)
  end

  @impl true
  def handle_event(
        "add_read_model",
        %{"read_model" => read_model, "dispatched_by_id" => dispatched_by_id},
        socket

      ) do

    dispatched_by_component = Enum.find(socket.assigns.flow["components"], fn component -> dispatched_by_id == component["gui_id"] end)
    |> fn comp -> %{"name" => comp["name"], "type" => comp["type"]} end.()


    component = [
      %{
        "type" => "read_model",
        "name" => read_model,
        "dispatched_by_component" => [dispatched_by_component],
        "dispatched_by_id" => dispatched_by_id,
        "gui_id" => UUID.uuid1(),
      }
    ]

    update_flow(component, socket)
  end

  @impl true
  def handle_event(
        "add_processer",
        %{"processer" => processer, "dispatched_by_id" => dispatched_by_id},
        socket
      ) do
    dispatched_by_component = Enum.find(socket.assigns.flow["components"], fn component -> dispatched_by_id == component["gui_id"] end)
    |> fn comp -> %{"name" => comp["name"], "type" => comp["type"]} end.()

    component = [
      %{
        "type" => "processer",
        "name" => processer,
        "dispatched_by_id" => dispatched_by_id,
        "dispatched_by_component" => [dispatched_by_component],
        "gui_id" => UUID.uuid1(),
      }
    ]

    update_flow(component, socket)
  end

  def handle_event("generate_files", %{"app_name" => app_name}, socket) do

  	 flow = socket.assigns.flows |> Map.values  |> Enum.at(0)
     merge_dispatched_by  =
     flow["components"]
     |> Enum.reduce(%{}, fn component, acc ->
       case Map.get(acc, component["name"]) do
         nil ->
           Map.put(acc, component["name"], component)

         x -> disp_by_name = nil_to_empty_array(x["dispatched_by_component"]) ++ component["dispatched_by_component"]
         			new_comp = Map.put(component, "dispatched_by_component", disp_by_name)
         			Map.put(acc, component["name"], new_comp)
        end
        end)

     components_with_dispatched =
     Map.values(merge_dispatched_by)
     |> Enum.reduce(merge_dispatched_by, fn component, acc ->
        components_dispatched_by_me =
        Enum.filter(Map.values(merge_dispatched_by), fn comp -> Enum.member?(Enum.map(comp["dispatched_by_component"], fn comp -> comp["name"] end), component["name"]) end)
        |> Enum.map(fn full_comp -> %{"name" => full_comp["name"], "type" => full_comp["type"]} end )

        updated_comp = Map.get(acc, component["name"])
        |> Map.put("dispatches", components_dispatched_by_me)
        Map.put(acc, component["name"], updated_comp)
        end)


    IO.inspect "components with dispatched by me"
    IO.inspect components_with_dispatched

    id = UUID.uuid1()

    res = File.mkdir("priv/static/boilerplates/#{id}")
    res = File.mkdir("priv/static/boilerplates/#{id}/views")
    res = File.mkdir("priv/static/boilerplates/#{id}/commands")
    res = File.mkdir("priv/static/boilerplates/#{id}/events")
    res = File.mkdir("priv/static/boilerplates/#{id}/aggregates")
    res = File.mkdir("priv/static/boilerplates/#{id}/read_models")
    res = File.mkdir("priv/static/boilerplates/#{id}/processes")

    components_with_dispatched
    |> Map.values
    |> Enum.each(fn comp ->
      case comp["type"] do
        "view" -> File.write("priv/static/boilerplates/#{id}/views/#{comp['name']}",
        """
        	defmodule FlowitScaffold do
          	use #{app_name}Web, :live_view
         end
        """)
       _ -> nil
       end
       end)



    id = UUID.uuid1()
    res = File.mkdir("priv/static/boilerplates")
    IO.inspect(res)
    File.write("priv/static/boilerplates/#{id}.csv", "hei")
    {:noreply, socket |> redirect(to: "/boilerplates/#{id}.csv")}
  end

  defp nil_to_empty_array(nil), do: []
  defp nil_to_empty_array(x), do: x

  def get_aggregates(components) do
    components
    |> Enum.filter(fn x -> x["type"] == "event" end)
    |> Enum.map(fn event -> event["aggregate"] end)
    |> Enum.uniq()
  end

  defp aggregate_height(i), do: (8 + 1.5 * i) * @height_unit

  defp event_height(event_component, aggregates) do
    Enum.find_index(aggregates, fn x -> x == event_component["aggregate"] end)
    |> aggregate_height
  end

  defp left_shift(_component, i), do: (4 + i) * @width_unit

  def render(assigns) do
    ~H"""

    <div class="shadow drawer drawer-mobile h-full min-h-screen w-full min-w-screen">
      <input id="my-drawer-2" type="checkbox" class="drawer-toggle">
      <div class="flex flex-col drawer-content">
        <div class="md:hidden">
          <label for="my-drawer-2" class="mb-4 btn btn-primary drawer-button lg:hidden">open
            menu</label>
        </div>
        <div class="hidden lg:block">
          <div class="md:p-8">
            <h1 class="text-3xl font-bold">Generate Flows</h1>
          </div>
          <div class="py-40">
            <%= case @flow do %><%= nil -> %><%= _ -> %><%= flow_page(%{flow: @flow, aggregates: get_aggregates(@flow["components"]), myheight: 100}) %><%end %>
          </div>
        </div>
        <div class="text-xs text-center lg:hidden">
          Menu can be toggled on mobile size.<br>
          Resize the browser to see fixed sidebar on desktop size
        </div>
      </div>
      <div class="drawer-side">
        <ul class="menu p-4 overflow-y-auto w-80 bg-base-300 text-base-content">
            <%= if @flow do  %>
          	<h2 class="text-2xl mb-5"><%= @flow["name"] |> String.capitalize() %> </h2>

            <%= add_component_modal_button(%{flow: @flow}, "Add View ", "btn-info btn-solid") %><%= add_component_modal_button(%{flow: @flow}, "Add Command", "btn-error") %>
            <%= add_component_modal_button(%{flow: @flow}, "Add Event", "btn-warning") %>
            <%= add_component_modal_button(%{flow: @flow}, "Add Read model", "btn-success" ) %><%= add_component_modal_button(%{flow: @flow},  "Add Processer", "btn-secondary" ) %>

            <%end %>

          <h2 class="text-2xl mb-5">Flows</h2>
            <div class="my-0 mx-0 py-0">
              <ul class="list-disc my-0 mx-0">
                <%= for flow <- Map.keys(@flows) do %>
                	<li> <%= link flow, to: "/flows/#{flow}" %></li>
                <%end %>
                <div class="flex justify-center">
                <label for="my-modal-3" class=" btn btn-primary modal-button btn-circle  text-2xl ">+</label>
                </div>
              </ul>
            </div>
            <form phx-submit="generate_files" class="mt-20">
            	<div class="form-control">
        				<label class="label"><span class="label-text">Your app name </span></label> <input name="app_name" type="text" placeholder="myApp" class= "input input-bordered">
            		<button type="submit" class="mt-2 btn btn-neutral"> Generate files </button>



            	</div>
            </form>
            </ul>
            </div>
            </div>


    <%= if @flow do %>
    	<%= for component <- @flow["components"] do %>
    		<%= if component["dispatched_by_id"] != nil  do %>
          <script>
            new LeaderLine(
              document.getElementById("<%= component["dispatched_by_id"]%>"),
              document.getElementById("<%= component["gui_id"] %>")
            );
          </script>

    		<%end %>
    	<%end %>
    <%end %>

    <input type="checkbox" id="my-modal-3" class="modal-toggle">
    <div class="modal">
      <div class="modal-box relative">
        <h3 class="text-lg font-bold">Create flow</h3>
        <form phx-submit="create_flow">
          <div class="form-control">
            <label class="label"><span class=
            "label-text">Filename</span></label> <input name="flowname" type="text" placeholder="myflow" class="input input-bordered">
          </div>
          <div class="modal-action">
            <label for="my-modal-3" class="btn">Cancel</label>
            <button for="my-modal-3" type="submit" class="btn btn-primary">Create</button>
          </div>
        </form>
      </div>
    </div>


    """
  end

  def flow_page(assigns) do
    ~H"""
    <%= add_component_modal(%{flow: @flow}, "Add View ", "add_view", fn x -> view_form_custom_conent(x) end ) %>
    <%= add_component_modal(%{flow: @flow}, "Add Command", "add_command", fn x -> command_custom_form_custom_content(x) end, "btn-info" ) %>
    <%= add_component_modal(%{flow: @flow}, "Add Event", "add_event", fn x -> event_form_custom_content(x) end, "btn-warning" ) %>
    <%= add_component_modal(%{flow: @flow}, "Add Read model", "add_read_model", fn x -> read_model_custom_form_content(x) end, "btn-success" ) %>
    <%= add_component_modal(%{flow: @flow}, "Add Processer", "add_processer", fn x -> processer_custom_form_content(x) end, "btn-secondary" ) %>

    <div class="px-10 prose">
    <%= for {aggregate,i} <- Enum.with_index(@aggregates) do %>
    <div style={"position: absolute; top: #{aggregate_height(i)}px"} >
    <h3 class="text-2xl font-bold"> <%= aggregate %> </h3>
    <div class="divider w-screen"></div>
    </div>
    <% end %>
     <div>

    <%= for {component,i} <- Enum.with_index(@flow["components"]) do %>
    <%=  case component["type"] do %>

    <%= "view" -> %>
    	<div id={component["gui_id"]}  class="flex bg-white border-4 text-center justify-center" style={"width:200px; height:200px; position: absolute; top: #{(1)*@myheight}px; left: #{left_shift(component,i)}px"} >
    	<h3 class="my-auto font-bold text-2xl"> <%= component["name"]  %> </h3>

    	</div>
    <%= "command" -> %>
    <div class="btn btn-info" id={component["gui_id"]} style={"position: absolute; top: #{(4)*@myheight}px; left: #{left_shift(component,i)}px"} >
    <%= component["name"] %>
    </div>

    <%= "event" -> %>
    <div class="btn btn-warning"  id={component["gui_id"]}   style={"position: absolute; top: #{event_height(component, @aggregates)}px; left: #{left_shift(component,i)}px"} >
    <%= component["name"] %>
    </div>

    <%= "processer" -> %>
    <div class="" id={component["gui_id"]}    style={"position: absolute; top: #{(1)*@myheight}px; left: #{left_shift(component,i)}px"} >
    <img class="mx-auto" width="60px" src="https://pngset.com/images/gears-cogs-gear-vector-gray-world-of-warcraft-transparent-png-606080.png" />

    <%= (component["name"]) %>
    </div>

    <%= "read_model" -> %>
    <div id={component["gui_id"]} class="btn btn-success" style={"position: absolute; top: #{(4)*@myheight}px; left: #{left_shift(component,i)}px"} >
    <%= (component["name"]) %>
    </div>

    <%= _ -> %> <div class="btn btn-info" style={"position: absolute; top: #{(5)*@myheight}px; left: (i + 2)*@myheightpx"} > hei </div>
    <% end %>
    <% end %>

    </div>
    </div>
    """
  end

  def view_form_custom_conent(assigns) do
    ~H"""
                  <div class="form-control">
                    <label class="label"><span class=
                    "label-text">name</span></label> <input name="name"
                    type="text" placeholder="a_view"  class=
                    "input input-bordered">
                  </div>
    """
  end

  def add_component_modal_button(assigns, title, button_style) do
    ~H"""

    <div class="px-10 pb-5 ">
    <label for={title} class={"btn modal-button " <> button_style } >  <%= title %> </label>
    </div>
    """
  end

  def add_component_modal(assigns, title, submit, custom_content, button_style \\ "") do
    ~H"""

            <input type="checkbox" id={title} class="modal-toggle">
            <div class="modal ">
              <div class="modal-box zIndex">
              <div class="zIndex">
                <h4 class="text-xl font-bold"><%= title %> </h4>
                <form phx-submit={submit} >
                  <%= custom_content.(%{flow: @flow}) %>
                  <%= dispatched_by_select(%{flow: @flow}) %>
                  <div class="modal-action">
                    <button for={title} type="submit" class="btn btn-primary btn-md zIndex"> Create </button>
                    <label for={title} class="btn btn-md">Close</label>
                  </div>
                </form>
              </div>
              </div>
            </div>
    """
  end

  def dispatched_by_select(assigns) do
    ~H"""
    <div class="form-control">
    <label class="label mt-5"><span class="label-text">Dispatched
    by</span></label> <select name="dispatched_by_id" class=
    "select select-bordered w-full max-w-xs">
      <option selected="selected">
        None
      </option><%= for component <- @flow["components"]do %>
      <option value={component["gui_id"]}>
        <%= component["name"] %>
      </option><%end %>
    </select>
    </div>
    """
  end

  def read_model_custom_form_content(assigns) do
    ~H"""
      <div class="form-control">
        <label class="label"><span class="label-text">
        read_model </span></label> <input name="read_model"
        type="text" placeholder="payments" class=
        "input input-bordered">
        </div>
    """
  end

  def processer_custom_form_content(assigns) do
    ~H"""
      <div class="form-control">
        <label class="label"><span class="label-text">
        Processer </span></label> <input name="processer"
        type="text" placeholder="payments" class=
        "input input-bordered">
        </div>

    """
  end

  def command_custom_form_custom_content(assigns) do
    ~H"""
    <div class="form-control">
    <label class="label"><span class=
    "label-text">Command</span></label> <input name="command"
    type="text" placeholder="pay" class= "input input-bordered">
    <label class="label"><span class=
    "label-text">Command params, space separated </span></label> <input name="command_params" type="text"  placeholder="amount reciever recipient" class="input input-bordered">
    </div>
    """
  end

  def event_form_custom_content(assigns) do
    ~H"""
      <div class="form-control">
        <label class="label"><span class=
        "label-text">Event name</span></label> <input name="event"
        type="text" placeholder="paid" class= "input input-bordered">

        <label class="label"><span class=
        "label-text">event params, space separated </span></label> <input name="event_params"
        type="text"  placeholder="amount reciever recipient" class=
        "input input-bordered">

        <label class="label"><span class=
        "label-text"> aggregate </span></label> <input name="aggregate"
        type="text"  placeholder="paymentaggregate" class=
        "input input-bordered">
      </div>

    """
  end
end
